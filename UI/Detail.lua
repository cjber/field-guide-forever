---@type string, FGNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class FGDetail
local Detail = {}
ns.Detail = Detail

local PANE_WIDTH, PANE_HEIGHT = 582, 514
local PIPS = { "Discovered", "Observed", "Studied", "Mastered" }
-- The Pet Journal's card across the top: a 90 Collections border round a 72 portrait, then name, rank and the bar.
local CARD_HEIGHT = 156
local PORTRAIT_BORDER = 90
local TEXT_X = 120
local BAR_WIDTH = PANE_WIDTH - 24 - TEXT_X
local SECTION_X = 14
local VARIANTS_Y = -172
local SLOT_SIZE, SLOT_MARK = 70, 46
local SLOT_SPAN = (PANE_WIDTH - SECTION_X * 2) / 4
local LOWER_Y = -340
local RECORDS_WIDTH = 250
local HABITAT_X = SECTION_X + RECORDS_WIDTH + 20
local HABITAT_WIDTH = PANE_WIDTH - SECTION_X - HABITAT_X
-- A zone map is 1002 by 668; the frame shows all of it at that aspect, inside the inset's 3 edge.
local MAP_WIDTH, MAP_HEIGHT = 174, 116
local SIDE_X = HABITAT_X + MAP_WIDTH + 16
local SIDE_WIDTH = PANE_WIDTH - SECTION_X - SIDE_X
local LADDER = {
	{ tier = "bronze", label = "Bronze", odds = 1, every = true },
	{ tier = "silver", label = "Silver", odds = 25 },
	{ tier = "gold", label = "Gold", odds = 100 },
	{ tier = "shiny", label = "Shiny", odds = 1000 },
}
local RECORD_ROWS = 5

local currentMap

---@class FGVariantSlot : Frame
---@field Glow Texture
---@field Border Texture
---@field Icon Texture
---@field Title FontString
---@field Status FontString

---@param parent Frame
---@param tier string
---@param index integer
---@return FGVariantSlot
local function CreateSlot(parent, tier, index)
	local slot = CreateFrame("Frame", nil, parent) --[[@as FGVariantSlot]]
	slot:SetSize(SLOT_SPAN, 112)
	slot:SetPoint("TOPLEFT", parent, "TOPLEFT", SECTION_X + (index - 1) * SLOT_SPAN, VARIANTS_Y - 40)
	slot.Border = slot:CreateTexture(nil, "ARTWORK")
	slot.Border:SetSize(SLOT_SIZE, SLOT_SIZE)
	slot.Border:SetPoint("TOP", slot, "TOP", 0, 0)
	slot.Glow = slot:CreateTexture(nil, "BACKGROUND")
	slot.Glow:SetAtlas("collections-upgradeglow")
	slot.Glow:SetBlendMode("ADD")
	slot.Glow:SetSize(SLOT_SIZE + 52, SLOT_SIZE + 52)
	slot.Glow:SetPoint("CENTER", slot.Border, "CENTER")
	slot.Glow:Hide()
	slot.Icon = slot:CreateTexture(nil, "OVERLAY")
	slot.Icon:SetPoint("CENTER", slot.Border, "CENTER")
	Art.PaintTierIcon(slot.Icon, tier, SLOT_MARK)
	slot.Title = Art.Text(slot, "GameFontNormalLarge", "muted")
	slot.Title:SetPoint("TOP", slot, "TOP", 0, -SLOT_SIZE - 6)
	slot.Title:SetWidth(SLOT_SPAN)
	slot.Title:SetJustifyH("CENTER")
	slot.Status = Art.Text(slot, "GameFontHighlight", "muted")
	slot.Status:SetPoint("TOP", slot, "TOP", 0, -SLOT_SIZE - 28)
	slot.Status:SetWidth(SLOT_SPAN)
	slot.Status:SetJustifyH("CENTER")
	return slot
end

---@param parent Frame
function Detail.Create(parent)
	Detail.parent = parent
	local content = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	content:SetPoint("TOPLEFT", 0, 0)
	content:SetSize(PANE_WIDTH, PANE_HEIGHT)
	Detail.content = content
	parent = content
	currentMap = nil

	-- The Pet Journal's own card behind the creature, closed by the Challenge Mode divider.
	local card = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
	card:SetAtlas("PetJournal-PetCard-BG")
	card:SetPoint("TOPLEFT", 4, -4)
	card:SetSize(PANE_WIDTH - 8, CARD_HEIGHT)
	local divider = parent:CreateTexture(nil, "BORDER")
	divider:SetAtlas("ChallengeMode-ThinDivider")
	divider:SetPoint("TOPLEFT", 4, -4 - CARD_HEIGHT + 1)
	divider:SetSize(PANE_WIDTH - 8, 3)

	Detail.portrait, Detail.portraitBorder = Art.BorderedIcon(parent, PORTRAIT_BORDER)
	Detail.portrait:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -22)

	Detail.name = Art.Text(parent, "GameFontHighlightHuge", "gold")
	Detail.name:SetPoint("TOPLEFT", parent, "TOPLEFT", TEXT_X, -20)
	Detail.name:SetSize(BAR_WIDTH, 24)
	Detail.name:SetJustifyH("LEFT")
	Detail.name:SetWordWrap(false)
	Detail.sub = Art.Text(parent, "GameFontHighlight", "text")
	Detail.sub:SetPoint("TOPLEFT", parent, "TOPLEFT", TEXT_X, -50)
	Detail.sub:SetSize(BAR_WIDTH, 16)
	Detail.sub:SetJustifyH("LEFT")
	Detail.sub:SetWordWrap(false)

	Detail.rank = Art.Text(parent, "GameFontNormalLarge", "gold")
	Detail.rank:SetPoint("TOPLEFT", parent, "TOPLEFT", TEXT_X, -78)
	Detail.rank:SetWidth(BAR_WIDTH)
	Detail.rank:SetJustifyH("LEFT")
	Detail.specimenCount = Art.Text(parent, "GameFontHighlight", "text")
	Detail.specimenCount:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, -80)
	Detail.specimenCount:SetWidth(220)
	Detail.specimenCount:SetJustifyH("RIGHT")
	Detail.specimenBar = Art.ObjectiveBar(parent, BAR_WIDTH, #PIPS)
	Detail.specimenBar:SetPoint("TOPLEFT", parent, "TOPLEFT", TEXT_X, -100)
	Detail.pips = {}
	for index, pip in ipairs(PIPS) do
		local label = Art.Text(parent, "GameFontHighlightSmall", "muted")
		label:SetPoint("TOPLEFT", parent, "TOPLEFT", TEXT_X + (index - 1) * BAR_WIDTH / #PIPS, -126)
		label:SetWidth(BAR_WIDTH / #PIPS)
		label:SetJustifyH("CENTER")
		label:SetText(L[pip])
		Detail.pips[index] = label
	end
	Detail.hint = Art.Text(parent, "GameFontHighlight", "text")
	Detail.hint:SetPoint("TOPLEFT", parent, "TOPLEFT", TEXT_X, -104)
	Detail.hint:SetWidth(BAR_WIDTH)
	Detail.hint:SetJustifyH("LEFT")
	Detail.hint:SetText(L["Defeat one to add it, then watch for its rarer variants."])

	Detail.variantsBand, Detail.variantsTitle = Art.Header(parent, L["Variants"], 300)
	Detail.variantsBand:SetPoint("TOPLEFT", parent, "TOPLEFT", SECTION_X, VARIANTS_Y)
	Detail.slots = {}
	for index, entry in ipairs(LADDER) do
		Detail.slots[entry.tier] = CreateSlot(parent, entry.tier, index)
	end

	Detail.recordsBand, Detail.recordsTitle = Art.Header(parent, L["Records"], RECORDS_WIDTH)
	Detail.recordsBand:SetPoint("TOPLEFT", parent, "TOPLEFT", SECTION_X, LOWER_Y)
	Detail.records = {}
	for index = 1, RECORD_ROWS do
		local y = LOWER_Y - 40 - (index - 1) * 22
		local key = Art.Text(parent, "GameFontHighlight", "muted")
		key:SetPoint("TOPLEFT", parent, "TOPLEFT", SECTION_X + 12, y)
		key:SetWidth(130)
		key:SetJustifyH("LEFT")
		key:SetWordWrap(false)
		local value = Art.Text(parent, "GameFontHighlight", "text")
		value:SetPoint("TOPRIGHT", parent, "TOPLEFT", SECTION_X + RECORDS_WIDTH - 10, y)
		value:SetWidth(RECORDS_WIDTH - 152)
		value:SetJustifyH("RIGHT")
		value:SetWordWrap(false)
		Detail.records[index] = { key = key, value = value }
	end

	Detail.habitatBand, Detail.habitatTitle = Art.Header(parent, L["Habitat"], HABITAT_WIDTH)
	Detail.habitatBand:SetPoint("TOPLEFT", parent, "TOPLEFT", HABITAT_X, LOWER_Y)
	Detail.location = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	Detail.location:SetPoint("TOPLEFT", HABITAT_X, LOWER_Y - 38)
	Detail.location:SetSize(MAP_WIDTH + 6, MAP_HEIGHT + 6)
	Detail.map = Art.ZoneMap(Detail.location, MAP_WIDTH, MAP_HEIGHT)
	Detail.map:SetPoint("TOPLEFT", 3, -3)
	-- Zones without map art keep the client's own zone illustration.
	Detail.locationArt = Detail.location:CreateTexture(nil, "ARTWORK")
	Detail.locationArt:SetPoint("TOPLEFT", 3, -3)
	Detail.locationArt:SetSize(MAP_WIDTH, MAP_HEIGHT)
	Detail.locationArt:SetTexCoord(0, 1, 0, 1)
	Detail.locationName = Art.Text(parent, "GameFontNormalLarge", "gold")
	Detail.locationName:SetPoint("TOPLEFT", SIDE_X, LOWER_Y - 42)
	Detail.locationName:SetWidth(SIDE_WIDTH)
	Detail.locationName:SetJustifyH("LEFT")
	Detail.locationName:SetMaxLines(3)
	Detail.mapButton = CreateFrame("Button", nil, parent, "SharedButtonSmallTemplate")
	Detail.mapButton:SetPoint("TOPLEFT", SIDE_X, LOWER_Y - 38 - MAP_HEIGHT + 18)
	Detail.mapButton:SetSize(SIDE_WIDTH, 24)
	Detail.mapButton:SetText(L["Open map"])
	Detail.mapButton:SetScript("OnClick", function()
		if currentMap then
			C_Map.OpenWorldMap(currentMap)
		end
	end)
end

---@param zone FGZone
local function UpdateLocation(zone)
	local area, overrides = ns.QuestieDB.AreaMaps()
	local map = (overrides and overrides[zone.id]) or (area and area[zone.id])
	currentMap = map and map > 0 and map or nil
	Detail.locationName:SetText(L[zone.name])
	Detail.locationName:Show()
	Detail.mapButton:SetEnabled(currentMap ~= nil)
	Detail.mapButton:SetShown(currentMap ~= nil)
	local drawn = Art.SetZoneMap(Detail.map, currentMap)
	local art = not drawn and Art.LOCATION_ART[zone.id] or nil
	Detail.locationArt:SetTexture(art)
	Detail.locationArt:SetShown(art ~= nil)
	Detail.map:SetShown(drawn)
	Detail.location:SetShown(drawn or art ~= nil)
end

---@param entry FGSpeciesState?
local function UpdateResearch(entry)
	local count = entry and entry.count or 0
	local rank = ns.Model.Rank(count)
	local known = count > 0
	Detail.rank:SetText(known and L[PIPS[rank]] or L["Not yet in your journal"])
	Detail.rank:SetTextColor(Art.RGBA(known and "gold" or "muted", 1))
	Detail.specimenCount:SetText(string.format(L["%d / %d sightings"], count, ns.Model.MASTERED_AT))
	Detail.specimenCount:SetShown(known)
	Detail.specimenBar:SetShown(known)
	Detail.hint:SetShown(not known)
	-- Each quarter of the bar is one rank, filled by the sightings between that rank and the next.
	local bounds = { 0, 1, 3, 6, ns.Model.MASTERED_AT }
	local filled = 0
	for index = 1, #PIPS do
		local low, high = bounds[index], bounds[index + 1]
		filled = filled + math.max(0, math.min(1, (count - low) / (high - low)))
	end
	Detail.specimenBar:SetFraction(filled / #PIPS)
	for index, label in ipairs(Detail.pips) do
		label:SetShown(known)
		label:SetTextColor(Art.RGBA(rank >= index and "text" or "muted", 1))
	end
end

---@param tier string
---@return string
local function TierName(tier)
	return L[tier:sub(1, 1):upper() .. tier:sub(2)]
end

---@param tier string
---@param variant FGVariant
---@param odds integer
---@param every boolean?
---@return string
local function SlotStatus(tier, variant, odds, every)
	if variant.known then
		return tier == "shiny" and L["Found"] or string.format(L["Found %d"], variant.count)
	elseif every then
		return L["Every spawn"]
	end
	return string.format(L["1 in %d spawns"], odds)
end

---@param character FGState?
---@param species FGSpecies
local function UpdateVariants(character, species)
	local variants = ns.Model.Variants(character, species.id)
	for _, info in ipairs(LADDER) do
		local slot = Detail.slots[info.tier]
		local variant = variants[info.tier]
		Art.SetBorderCollected(slot.Border, variant.known)
		Art.PaintTierIcon(slot.Icon, info.tier, SLOT_MARK)
		slot.Icon:SetDesaturated(not variant.known)
		local shade = variant.known and 1 or 0.35
		slot.Icon:SetVertexColor(shade, shade, shade, variant.known and 1 or 0.8)
		slot.Glow:SetShown(variant.known and info.tier == "shiny")
		slot.Title:SetText(TierName(info.tier))
		if variant.known then
			local r, g, b = Art.RGBA(info.tier, 1)
			slot.Title:SetTextColor(r, g, b, 1)
		else
			slot.Title:SetTextColor(Art.RGBA("muted", 1))
		end
		slot.Status:SetText(SlotStatus(info.tier, variant, info.odds, info.every))
		slot.Status:SetTextColor(Art.RGBA(variant.known and "complete" or "muted", 1))
	end
end

---@param timestamp number?
---@return string?
local function FormatSeen(timestamp)
	if not timestamp then
		return nil
	end
	return date and (tostring(date("%d %b", timestamp)):gsub("^0", "")) or tostring(timestamp)
end
---@param species FGSpecies
---@param character FGState?
local function UpdateRecords(species, character)
	for _, row in ipairs(Detail.records) do
		row.key:SetText("")
		row.value:SetText("")
		row.key:Hide()
		row.value:Hide()
	end
	local options = ns.db and ns.db.options or {}
	local show = options.showSightingLog ~= false
	Detail.recordsTitle:SetShown(show)
	Detail.recordsBand:SetShown(show)
	if not show then
		return
	end
	local entry = ns.Model.Specimen(character, species.id)
	local pairs = {}
	if entry.count == 0 then
		pairs[1] = { L["Nothing recorded yet."], "" }
	else
		pairs[#pairs + 1] = { L["Sightings"], tostring(entry.count) }
		if (entry.kills or 0) > 0 then
			pairs[#pairs + 1] = { L["Deaths recorded"], tostring(entry.kills) }
		end
		local firstSeen = FormatSeen(entry.firstSighting or entry.firstKill)
		if firstSeen then
			pairs[#pairs + 1] = { L["First seen"], firstSeen }
		end
		local lastSeen = FormatSeen(entry.lastKill)
		if lastSeen then
			pairs[#pairs + 1] = { L["Last seen"], lastSeen }
		end
		local best = ns.Model.BestTier(entry)
		if best then
			pairs[#pairs + 1] = { L["Best variant"], TierName(best) }
		end
	end
	for index, pair in ipairs(pairs) do
		local row = Detail.records[index]
		if row then
			row.key:SetWidth(pair[2] == "" and RECORDS_WIDTH - 24 or 130)
			row.key:SetText(pair[1])
			row.value:SetText(pair[2])
			row.key:Show()
			row.value:Show()
		end
	end
end

---@param shown boolean
local function SetEntryShown(shown)
	Detail.portrait:SetShown(shown)
	Detail.portraitBorder:SetShown(shown)
	Detail.rank:SetShown(shown)
	Detail.variantsBand:SetShown(shown)
	Detail.variantsTitle:SetShown(shown)
	for _, slot in pairs(Detail.slots) do
		slot:SetShown(shown)
	end
	Detail.recordsBand:SetShown(shown)
	Detail.recordsTitle:SetShown(shown)
	Detail.habitatBand:SetShown(shown)
	Detail.habitatTitle:SetShown(shown)
	for _, row in ipairs(Detail.records) do
		row.key:SetShown(shown)
		row.value:SetShown(shown)
	end
	if not shown then
		Detail.specimenCount:Hide()
		Detail.specimenBar:Hide()
		Detail.hint:Hide()
		for _, label in ipairs(Detail.pips) do
			label:Hide()
		end
	end
end

---@param species FGSpecies?
---@param character FGState? the character's saved state, not one species' entry
---@param zone FGZone?
function Detail.Show(species, character, zone)
	if not species or not zone then
		currentMap = nil
		SetEntryShown(false)
		Detail.location:Hide()
		Detail.locationName:SetText("")
		Detail.locationName:Hide()
		Detail.mapButton:Disable()
		Detail.mapButton:Hide()
		Detail.name:SetTextColor(Art.RGBA("text", 1))
		Detail.name:SetText(L["Select a creature to read its entry."])
		Detail.sub:SetText("")
		return
	end
	SetEntryShown(true)
	Detail.name:SetText(species.name)
	Detail.sub:SetText(
		string.format(
			L["%s · %s · Level %s"],
			L[species.family],
			L[zone.name],
			ns.Model.LevelRange(species.minLevel, species.maxLevel)
		)
	)
	local entry = character and character.species and character.species[species.id] or nil
	local known = entry ~= nil and (entry.count or 0) > 0
	Art.CreatureIcon(Detail.portrait, species.name, species.id, PORTRAIT_BORDER - 18)
	Detail.portrait:SetDesaturated(not known)
	local shade = known and 1 or 0.12
	Detail.portrait:SetVertexColor(shade, shade, shade, 1)
	Detail.name:SetTextColor(Art.RGBA(known and "gold" or "muted", 1))
	Art.SetBorderCollected(Detail.portraitBorder, known)
	UpdateResearch(entry)
	UpdateVariants(character, species)
	UpdateRecords(species, character)
	UpdateLocation(zone)
end
