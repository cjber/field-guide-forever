---@type string, FGNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class FGDetail
local Detail = {}
ns.Detail = Detail

local PANE_WIDTH, PANE_HEIGHT = 582, 514
local INNER_WIDTH = 554
local PIPS = { "Discovered", "Observed", "Studied", "Mastered" }
-- The three collectible forms, as Wardrobe cards across the top of the entry.
local KINDS = { "common", "rare", "shiny" }
local CARD_WIDTH, CARD_HEIGHT, CARD_GAP = 164, 219, 20
local CARD_ICON = 72
local SHINY_SPARKLES = { { 0.36, -0.44, 16 }, { -0.44, -0.30, 11 }, { 0.48, 0.20, 9 } }

local modelSpecies
local currentMap

---@class FGVariantCard : Frame
---@field kind FGVariantKind
---@field Border Texture
---@field Glow Texture
---@field Icon Texture
---@field IconBorder Texture
---@field Unknown FontString
---@field Sparkles Texture[]
---@field Title FontString
---@field Status FontString

---@param parent Frame
---@param kind FGVariantKind
---@param index integer
---@return FGVariantCard
local function CreateCard(parent, kind, index)
	local card = CreateFrame("Frame", nil, parent) --[[@as FGVariantCard]]
	card.kind = kind
	card:SetSize(CARD_WIDTH, CARD_HEIGHT)
	local left = (PANE_WIDTH - (3 * CARD_WIDTH + 2 * CARD_GAP)) / 2
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", left + (index - 1) * (CARD_WIDTH + CARD_GAP), -64)
	-- The Appearances tab's own collected and uncollected card frames.
	card.Glow = card:CreateTexture(nil, "BACKGROUND")
	card.Glow:SetAtlas("collections-upgradeglow")
	card.Glow:SetBlendMode("ADD")
	-- A halo behind the shiny icon only, so the card's title and status stay readable.
	card.Glow:SetPoint("CENTER", card, "TOP", 0, -82)
	card.Glow:SetSize(CARD_ICON + 48, CARD_ICON + 48)
	card.Border = card:CreateTexture(nil, "BORDER")
	card.Border:SetAllPoints()
	card.Icon = card:CreateTexture(nil, "ARTWORK")
	card.Icon:SetSize(CARD_ICON, CARD_ICON)
	card.Icon:SetPoint("CENTER", card, "TOP", 0, -82)
	card.IconBorder = card:CreateTexture(nil, "OVERLAY")
	card.IconBorder:SetPoint("TOPLEFT", card.Icon, "TOPLEFT", -6, 6)
	card.IconBorder:SetPoint("BOTTOMRIGHT", card.Icon, "BOTTOMRIGHT", 6, -6)
	card.Unknown = card:CreateFontString(nil, "OVERLAY", "GameFontDisableHuge")
	card.Unknown:SetPoint("CENTER", card.Icon, "CENTER", 0, 0)
	card.Unknown:SetText(L["?"])
	card.Sparkles = {}
	for sparkleIndex, sparkle in ipairs(SHINY_SPARKLES) do
		local star = card:CreateTexture(nil, "OVERLAY", nil, 1)
		star:SetAtlas(Art.SHINY_STAR)
		star:SetBlendMode("ADD")
		star:SetSize(sparkle[3], sparkle[3])
		star:SetPoint("CENTER", card.Icon, "CENTER", sparkle[1] * 96, -sparkle[2] * 96)
		card.Sparkles[sparkleIndex] = star
	end
	card.Title = Art.Text(card, "GameFontNormalLarge", "gold")
	card.Title:SetPoint("TOP", 0, -150)
	card.Title:SetWidth(CARD_WIDTH)
	card.Title:SetJustifyH("CENTER")
	card.Status = Art.Text(card, "GameFontDisableSmall", "muted")
	card.Status:SetPoint("TOP", 0, -176)
	card.Status:SetWidth(CARD_WIDTH - 12)
	card.Status:SetJustifyH("CENTER")
	return card
end

---@param parent Frame
function Detail.Create(parent)
	Detail.parent = parent
	local content = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	content:SetPoint("TOPLEFT", 0, 0)
	content:SetSize(PANE_WIDTH, PANE_HEIGHT)
	Detail.content = content
	-- The Collections journal's own backdrop behind the cards.
	local backdrop = content:CreateTexture(nil, "BACKGROUND", nil, 1)
	backdrop:SetAtlas("Collections-background")
	backdrop:SetPoint("TOPLEFT", 3, -3)
	backdrop:SetPoint("BOTTOMRIGHT", -3, 3)
	parent = content
	modelSpecies = nil
	currentMap = nil
	Detail.name = Art.Text(parent, "GameFontNormalLarge", "gold")
	Detail.name:SetPoint("TOPLEFT", 14, -14)
	Detail.name:SetSize(INNER_WIDTH, 22)
	Detail.name:SetWordWrap(false)
	Detail.sub = Art.Text(parent, "GameFontHighlightSmall", "text")
	Detail.sub:SetPoint("TOPLEFT", 14, -38)
	Detail.sub:SetSize(INNER_WIDTH, 14)
	Detail.sub:SetWordWrap(false)

	Detail.cards = {}
	for index, kind in ipairs(KINDS) do
		Detail.cards[kind] = CreateCard(parent, kind, index)
	end
	-- The common card shows the live model once the form is collected; the icon covers it until the model loads.
	local common = Detail.cards.common
	Detail.portrait = common.Icon
	Detail.model = CreateFrame("PlayerModel", nil, common)
	Detail.model:SetPoint("TOPLEFT", 6, -10)
	Detail.model:SetSize(CARD_WIDTH - 12, 132)
	Detail.model:SetKeepModelOnHide(true)
	Detail.model:SetScript("OnModelLoaded", function(self)
		if modelSpecies and (self:GetModelFileID() or 0) > 0 then
			Detail.portrait:Hide()
			common.IconBorder:Hide()
		end
	end)

	local research = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	research:SetPoint("TOPLEFT", 14, -300)
	research:SetSize(INNER_WIDTH, 52)
	Detail.researchCard = research
	Detail.rank = Art.Text(research, "GameFontNormal", "gold")
	Detail.rank:SetPoint("TOPLEFT", 10, -8)
	Detail.rank:SetWidth(100)
	Detail.specimenCount = Art.Text(research, "GameFontHighlightSmall", "text")
	Detail.specimenCount:SetPoint("TOPRIGHT", -10, -8)
	Detail.specimenCount:SetWidth(350)
	Detail.specimenCount:SetJustifyH("RIGHT")
	Detail.specimenBar = Art.StatusBar(research, INNER_WIDTH - 20, 12, ns.Model.MASTERED_AT)
	Detail.specimenBar:SetPoint("TOPLEFT", 10, -30)

	-- Records and place, side by side under the research strip.
	Detail.recordsTitle = Art.Text(parent, "GameFontNormal", "gold")
	Detail.recordsTitle:SetPoint("TOPLEFT", 14, -370)
	Detail.recordsTitle:SetText(L["Records"])
	Detail.sightingText = Art.Text(parent, "GameFontHighlightSmall", "text")
	Detail.sightingText:SetPoint("TOPLEFT", 14, -392)
	Detail.sightingText:SetSize(350, 80)
	Detail.sightingText:SetJustifyH("LEFT")
	Detail.sightingText:SetJustifyV("TOP")
	Detail.sightingText:SetWordWrap(true)
	Detail.sightingText:SetMaxLines(4)
	Detail.sightingText:SetSpacing(4)

	Detail.location = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	Detail.location:SetPoint("TOPLEFT", 378, -364)
	Detail.location:SetSize(190, 112)
	Detail.location:SetClipsChildren(true)
	Detail.locationArt = Detail.location:CreateTexture(nil, "ARTWORK")
	Detail.locationArt:SetPoint("TOPLEFT", 6, -4)
	Detail.locationArt:SetSize(178, 104)
	Detail.locationArt:SetTexCoord(33 / 256, 223 / 256, 0, 1)
	Detail.locationName = Art.Text(parent, "GameFontNormal", "gold")
	Detail.locationName:SetPoint("TOPLEFT", 378, -484)
	Detail.locationName:SetSize(88, 16)
	Detail.locationName:SetWordWrap(false)
	Detail.mapButton = CreateFrame("Button", nil, parent, "SharedButtonSmallTemplate")
	Detail.mapButton:SetPoint("TOPLEFT", 470, -480)
	Detail.mapButton:SetSize(98, 22)
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
	Detail.mapButton:SetEnabled(currentMap ~= nil)
	Detail.mapButton:SetShown(currentMap ~= nil)
	local art = Art.LOCATION_ART[zone.id]
	Detail.locationArt:SetTexture(art)
	Detail.locationArt:SetShown(art ~= nil)
	Detail.locationName:SetShown(art ~= nil)
	Detail.location:SetShown(art ~= nil)
end

---@param state FGSpeciesState?
local function UpdateResearch(state)
	local count = state and state.count or 0
	local rank = ns.Model.Rank(count)
	Detail.rank:SetText(rank > 0 and L[PIPS[rank]] or L["Research"])
	local killCount = state and (state.kills or state.count) or 0
	local format = state and state.killsEstimated and "%d / %d · at least %d recorded deaths"
		or "%d / %d · %d recorded deaths"
	Detail.specimenCount:SetText(string.format(L[format], count, ns.Model.MASTERED_AT, killCount))
	Detail.specimenBar:SetValue(count)
end

-- What a card says under its title: collected, or how the form is earned.
---@param kind FGVariantKind
---@param variant FGVariant
---@param absent boolean
---@return string
local function CardStatus(kind, variant, absent)
	if absent then
		return L["Only rare creatures have one"]
	elseif variant.known then
		return L["Collected"]
	elseif kind == "common" then
		return L["Defeat one"]
	elseif kind == "rare" then
		return string.format(L["%d / %d rare kills"], variant.count, variant.target)
	end
	return string.format(L["1 in %d per kill"], ns.Model.SHINY_CHANCE)
end

local TITLES = { common = "Common", rare = "Rare", shiny = "Shiny" }

---@param card FGVariantCard
---@param variant FGVariant
---@param icon string
---@param absent boolean
local function UpdateCard(card, variant, icon, absent)
	local kind = card.kind
	local known = variant.known and not absent
	card.Border:SetAtlas(known and "transmog-wardrobe-border-collected" or "transmog-wardrobe-border-uncollected")
	card.Border:SetAlpha(absent and 0.5 or 1)
	card.Glow:SetShown(kind == "shiny" and known)
	for _, star in ipairs(card.Sparkles) do
		star:SetShown(kind == "shiny" and known)
	end
	card.Icon:SetShown(not absent)
	card.IconBorder:SetShown(not absent)
	card.Unknown:SetShown(not absent and not known)
	if not absent then
		Art.Icon(card.Icon, icon, CARD_ICON)
		-- Missing: the creature's silhouette, as the Appearances tab shows an item not yet collected.
		card.Icon:SetDesaturated(not known)
		local shade = known and 1 or 0.08
		card.Icon:SetVertexColor(shade, shade, shade, 1)
		card.IconBorder:SetAtlas(Art.VARIANT_BORDERS[kind])
		local edge = known and 1 or 0.45
		card.IconBorder:SetVertexColor(edge, edge, edge, 1)
	end
	card.Title:SetText(absent and L["No rare form"] or L[TITLES[kind]])
	card.Title:SetFontObject(known and "GameFontNormalLarge" or "GameFontNormal")
	local titleColor = (not known and "muted") or (kind == "rare" and "rare") or "gold"
	card.Title:SetTextColor(Art.RGBA(titleColor, 1))
	card.Status:SetText(CardStatus(kind, variant, absent))
	card.Status:SetFontObject(known and "GameFontHighlightSmall" or "GameFontDisableSmall")
	card.Status:SetTextColor(Art.RGBA(known and "complete" or "muted", 1))
end

---@param character FGState?
---@param species FGSpecies
local function UpdateCards(character, species)
	local variants = ns.Model.Variants(character, species.id)
	local icon = Art.SpeciesIcon(species.name, species.id)
	local noRare = not ns.Model.HasRareForm(character, species)
	for _, kind in ipairs(KINDS) do
		UpdateCard(Detail.cards[kind], variants[kind], icon, kind == "rare" and noRare)
	end
	Detail.model:SetShown(variants.common.known)
end

---@param species FGSpecies
---@param zone FGZone
local function UpdateSightings(species, zone)
	local options = ns.db and ns.db.options or {}
	local showLog = options.showSightingLog ~= false
	Detail.recordsTitle:SetShown(showLog)
	Detail.sightingText:SetShown(showLog)
	if not showLog then
		return
	end
	local lines = {}
	local record = ns.Model.Specimen(ns.GetCharacterState(false), species.id)
	local function AddLine(line)
		if #lines < 4 then
			lines[#lines + 1] = line
		end
	end
	local function FormatFirst(timestamp, place)
		if not timestamp then
			return nil
		end
		local stamp = date and date("%Y-%m-%d %H:%M", timestamp) or tostring(timestamp)
		local location = place and place ~= "" and (L[place] or place) or L["Unknown instance"]
		return string.format(L["%s · %s"], location, stamp)
	end
	local firstSighting = FormatFirst(record.firstSighting, record.firstSightingZone)
	if firstSighting then
		AddLine(string.format(L["Personal first sighting: %s"], firstSighting))
	end
	local firstKill = FormatFirst(record.firstKill, record.firstKillZone)
	if firstKill then
		AddLine(string.format(L["First death observed: %s"], firstKill))
	end
	local firstRare = FormatFirst(record.firstRare, record.firstRareZone)
	if firstRare then
		AddLine(string.format(L["First rare recorded: %s"], firstRare))
	end
	local firstShiny = FormatFirst(record.firstShiny, record.firstShinyZone)
	if firstShiny then
		AddLine(string.format(L["First shiny recorded: %s"], firstShiny))
	end
	for _, entry in ipairs(ns.Model.GetSightings()) do
		if #lines >= 4 then
			break
		end
		if entry.species == species.name and entry.zone == zone.name then
			local stamp = date and date("%H:%M", entry.time) or tostring(entry.time)
			local kind = L["Kill"]
			if entry.kind == "rare" then
				kind = L["Rare"]
			elseif entry.kind == "shiny" then
				kind = L["Shiny"]
			elseif entry.kind == "sighting" then
				kind = L["First sighting"]
			end
			AddLine(string.format(L["%s · %s · %s"], stamp, L[entry.zone] or entry.zone, kind))
		end
	end
	if #lines == 0 then
		Detail.sightingText:SetText(L["No sightings yet this session."])
	else
		Detail.sightingText:SetText(table.concat(lines, "\n"))
	end
end

---@param shown boolean
local function SetEntryShown(shown)
	for _, card in pairs(Detail.cards) do
		card:SetShown(shown)
	end
	Detail.researchCard:SetShown(shown)
	Detail.recordsTitle:SetShown(shown)
	Detail.sightingText:SetShown(shown)
end

---@param species FGSpecies?
---@param character FGState? the character's saved state, not one species' entry
---@param zone FGZone?
function Detail.Show(species, character, zone)
	if not species or not zone then
		modelSpecies = nil
		currentMap = nil
		Detail.model:ClearModel()
		Detail.model:Hide()
		SetEntryShown(false)
		Detail.location:Hide()
		Detail.locationName:SetText("")
		Detail.locationName:Hide()
		Detail.mapButton:Disable()
		Detail.mapButton:Hide()
		Detail.name:SetText(L["Select a creature to read its entry."])
		Detail.sub:SetText("")
		Detail.sightingText:SetText("")
		return
	end
	SetEntryShown(true)
	if modelSpecies ~= species.id then
		Detail.model:ClearModel()
		modelSpecies = species.id
		Detail.model:SetCreature(species.id)
		Detail.model:SetCamDistanceScale(1)
		Detail.model:SetPortraitZoom(0)
		Detail.model:SetFacing(0.3)
	end
	UpdateLocation(zone)
	Detail.name:SetText(species.name)
	Detail.sub:SetText(
		string.format(
			L["%s · %s · Level %s"],
			L[species.family],
			L[zone.name],
			ns.Model.LevelRange(species.minLevel, species.maxLevel)
		)
	)
	local state = character and character.species and character.species[species.id] or nil
	UpdateResearch(state)
	UpdateCards(character, species)
	-- A model that already loaded for this species keeps the icon hidden; a new one shows it until it loads.
	local loaded = Detail.model:IsShown() and (Detail.model:GetModelFileID() or 0) > 0
	Detail.portrait:SetShown(not loaded)
	Detail.cards.common.IconBorder:SetShown(not loaded)
	UpdateSightings(species, zone)
end
