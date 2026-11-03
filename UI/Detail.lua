---@type string, FGNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class FGDetail
local Detail = {}
ns.Detail = Detail

local CARD_WIDTH = 554
local PIPS = { "Discovered", "Observed", "Studied", "Mastered" }
local REWARDS = { "Field sketch", "Ink study", "Brass plate", "Gilded entry" }

-- The model and research strip stay fixed while secondary pages share the same bounds.
local selectedPage = 1
local modelSpecies
local currentMap

---@param parent Frame
---@param x number
---@param y number
---@param width number
---@param height number
---@return Frame
local function Card(parent, x, y, width, height)
	local card = CreateFrame("Frame", nil, parent)
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	card:SetSize(width, height)
	return card
end

---@param page integer
function Detail.SetPage(page)
	selectedPage = page
	for index, panel in ipairs(Detail.pages) do
		panel:SetShown(index == page)
		if index == page then
			PanelTemplates_SelectTab(Detail.tabs[index])
		else
			PanelTemplates_DeselectTab(Detail.tabs[index])
		end
	end
end

---@class FGDetailParent: Frame
---@field minTabWidth number?
---@field maxTabWidth number?

---@param parent Frame
function Detail.Create(parent)
	---@cast parent FGDetailParent
	Detail.parent = parent
	parent.minTabWidth, parent.maxTabWidth = 104, 104
	modelSpecies = nil
	currentMap = nil
	Detail.name = Art.Text(parent, "GameFontNormalLarge", "gold")
	Detail.name:SetPoint("TOPLEFT", 14, -14)
	Detail.name:SetSize(CARD_WIDTH, 22)
	Detail.name:SetWordWrap(false)
	Detail.sub = Art.Text(parent, "GameFontDisableSmall", "muted")
	Detail.sub:SetPoint("TOPLEFT", 14, -42)
	Detail.sub:SetSize(CARD_WIDTH, 14)
	Detail.sub:SetWordWrap(false)

	Detail.model = CreateFrame("PlayerModel", nil, parent)
	Detail.model:SetPoint("TOPLEFT", 14, -68)
	Detail.model:SetSize(348, 240)
	Detail.model:SetKeepModelOnHide(true)
	Detail.model:SetScript("OnModelLoaded", function(self)
		if modelSpecies and (self:GetModelFileID() or 0) > 0 then
			Detail.portrait:Hide()
			Detail.modelNotice:Hide()
		end
	end)
	Detail.portrait = Art.Portrait(parent, 96)
	Detail.portrait:SetPoint("TOPLEFT", 140, -124)
	Detail.modelNotice = Art.Text(parent, "GameFontDisableSmall", "muted")
	Detail.modelNotice:SetPoint("TOPLEFT", 14, -238)
	Detail.modelNotice:SetSize(348, 28)
	Detail.modelNotice:SetJustifyH("CENTER")
	Detail.modelNotice:SetText(L["Creature portrait"])

	Detail.location = Card(parent, 378, -80, 190, 128)
	Detail.location:SetClipsChildren(true)
	Detail.locationArt = Detail.location:CreateTexture(nil, "ARTWORK")
	Detail.locationArt:SetPoint("TOPLEFT")
	Detail.locationArt:SetSize(190, 128)
	Detail.locationArt:SetTexCoord(33 / 256, 223 / 256, 0, 1)
	Detail.locationName = Art.Text(parent, "GameFontNormal", "gold")
	Detail.locationName:SetPoint("TOPLEFT", 378, -220)
	Detail.locationName:SetSize(190, 28)
	Detail.locationName:SetJustifyV("TOP")
	Detail.mapButton = CreateFrame("Button", nil, parent, "SharedButtonSmallTemplate")
	Detail.mapButton:SetPoint("TOPLEFT", 378, -258)
	Detail.mapButton:SetSize(120, 24)
	Detail.mapButton:SetText(L["Open map"])
	Detail.mapButton:SetScript("OnClick", function()
		if currentMap then
			C_Map.OpenWorldMap(currentMap)
		end
	end)

	local research = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	research:SetPoint("TOPLEFT", 14, -320)
	research:SetSize(CARD_WIDTH, 52)
	Detail.researchCard = research
	Detail.rank = Art.Text(research, "GameFontNormal", "gold")
	Detail.rank:SetPoint("TOPLEFT", 10, -8)
	Detail.rank:SetWidth(100)
	Detail.specimenCount = Art.Text(research, "GameFontDisableSmall", "text")
	Detail.specimenCount:SetPoint("TOPRIGHT", -10, -8)
	Detail.specimenCount:SetWidth(350)
	Detail.specimenCount:SetJustifyH("RIGHT")
	Detail.specimenBar = CreateFrame("StatusBar", nil, research)
	Detail.specimenBar:SetPoint("TOPLEFT", 10, -30)
	Detail.specimenBar:SetSize(CARD_WIDTH - 20, 12)
	Detail.specimenBar:SetMinMaxValues(0, ns.Model.MASTERED_AT)
	Detail.specimenBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	Detail.specimenBar:SetStatusBarColor(Art.RGBA("gold", 1))
	local background = Detail.specimenBar:CreateTexture(nil, "BACKGROUND")
	background:SetAtlas("Profession-ProgressBar-BG")
	background:SetAllPoints()
	local border = Detail.specimenBar:CreateTexture(nil, "OVERLAY")
	border:SetAtlas("Profession-ProgressBar-frame")
	border:SetAllPoints()

	Detail.pages, Detail.tabs = {}, {}
	for index, name in ipairs({ "Overview", "Variants", "Records" }) do
		local button = CreateFrame("Button", nil, parent, "PanelTabButtonTemplate")
		button:SetPoint("TOPLEFT", 14 + (index - 1) * 112, -380)
		button:SetText(L[name])
		PanelTemplates_TabResize(button, 0, 104, 104)
		button:SetScript("OnClick", function()
			Detail.SetPage(index)
		end)
		Detail.tabs[index] = button
		Detail.pages[index] = Card(parent, 14, -420, CARD_WIDTH, 80)
	end

	Detail.variants, Detail.rewards = {}, {}
	for index = 1, 3 do
		local row = Card(Detail.pages[2], 0, -(index - 1) * 24, CARD_WIDTH, 20)
		local name = Art.Text(row, "GameFontNormal", "text")
		name:SetPoint("LEFT", 0, 0)
		name:SetWidth(160)
		name:SetText(L[({ "Common", "Rare variant", "Shiny variant" })[index]])
		local tick = row:CreateTexture(nil, "OVERLAY")
		tick:SetPoint("LEFT", 176, 0)
		tick:SetSize(12, 12)
		local dash = Art.Text(row, "GameFontNormal", "muted")
		dash:SetPoint("LEFT", 176, 0)
		local status = Art.Text(row, "GameFontDisableSmall", "muted")
		status:SetPoint("LEFT", 202, 0)
		status:SetWidth(260)
		Detail.variants[index] = { frame = row, name = name, tick = tick, dash = dash, status = status }
	end
	Detail.badges = {}
	for index = 1, 4 do
		local row = Card(Detail.pages[3], 0, 0, 128, 16)
		local label = Art.Text(row, "GameFontDisableSmall", "text")
		label:SetAllPoints()
		label:SetWordWrap(false)
		Detail.badges[index] = { frame = row, text = label }
		local reward = Art.Text(Detail.pages[1], "GameFontDisableSmall", "text")
		reward:SetPoint("TOPLEFT", ((index - 1) % 2) * 277, -((index - 1) >= 2 and 24 or 0))
		reward:SetWidth(265)
		Detail.rewards[index] = reward
	end
	Detail.sightingCard = Card(Detail.pages[3], 0, -24, CARD_WIDTH, 56)
	Detail.sightingText = Art.Text(Detail.sightingCard, "GameFontDisableSmall", "text")
	Detail.sightingText:SetAllPoints()
	Detail.sightingText:SetJustifyH("LEFT")
	Detail.sightingText:SetJustifyV("TOP")
	Detail.sightingText:SetWordWrap(true)
	Detail.sightingText:SetMaxLines(3)
	Detail.SetPage(selectedPage)
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
	Detail.model:SetWidth(art and 348 or CARD_WIDTH)
	Detail.model:SetHeight((art or not currentMap) and 240 or 200)
	Detail.mapButton:ClearAllPoints()
	Detail.mapButton:SetPoint("TOPLEFT", art and 378 or 231, art and -258 or -282)
	Detail.portrait:ClearAllPoints()
	Detail.portrait:SetPoint("TOPLEFT", art and 140 or 243, -124)
	Detail.modelNotice:SetWidth(art and 348 or CARD_WIDTH)
end

---@param text FontString
---@param key string
---@param color string
local function SetLabelColor(text, key, color)
	text:SetText(L[key])
	local r, g, b = Art.RGBA(color, 1)
	text:SetTextColor(r, g, b, 1)
end

---@param species FGSpecies
---@param character FGState?
local function UpdateBadges(species, character)
	local variants = ns.Model.Variants(character, species.id)
	local labels = {
		{ key = "Common", color = "text", show = true },
		{ key = "Rare variant known", color = "rare", show = variants.rare.known },
		{ key = "Shiny seen", color = "shiny", show = variants.shiny.known },
		{ key = "Tracked", color = "complete", show = character and character.tracked == species.id },
	}
	local x = 0
	for index = 1, 4 do
		local badge = Detail.badges[index]
		local info = labels[index]
		if info.show then
			badge.text:SetText(L[info.key])
			local width = 128
			badge.frame:SetWidth(width)
			badge.frame:SetPoint("TOPLEFT", x, 0)
			local r, g, b = Art.RGBA(info.color, 1)
			badge.text:SetTextColor(r, g, b, 1)
			badge.frame:Show()
			x = x + width + 8
		else
			badge.frame:Hide()
		end
	end
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

---@param card table
---@param variant FGVariant
---@param color string
---@param knownText string
local function UpdateVariant(card, variant, color, knownText)
	if variant.known then
		card.tick:SetAtlas("common-icon-checkmark")
		card.tick:SetVertexColor(Art.RGBA(color, 1))
		card.dash:SetText("")
		card.status:SetText(knownText)
	else
		card.tick:SetTexture(nil)
		SetLabelColor(card.dash, "-", "muted")
		card.status:SetText(string.format(L["%d / %d"], variant.count, variant.target))
	end
end

---@param character FGState?
---@param species FGSpecies
local function UpdateVariants(character, species)
	local variants = ns.Model.Variants(character, species.id)
	UpdateVariant(Detail.variants[1], variants.common, "complete", L["Known"])
	UpdateVariant(Detail.variants[2], variants.rare, "rare", L["Known"])
	UpdateVariant(Detail.variants[3], variants.shiny, "gold", L["Known"])
end

---@param state FGSpeciesState?
local function UpdateRewards(state)
	local rank = ns.Model.Rank(state and state.count or 0)
	for index, label in ipairs(Detail.rewards) do
		local status = rank >= index and L["UNLOCKED"] or string.format(L["Locked · %s"], L[PIPS[index]])
		label:SetText(string.format(L["%s: %s"], L[REWARDS[index]], status))
	end
end

---@param species FGSpecies
---@param zone FGZone
local function UpdateSightings(species, zone)
	local options = ns.db and ns.db.options or {}
	local showLog = options.showSightingLog ~= false
	Detail.sightingCard:SetShown(showLog)
	if not showLog then
		return
	end
	local lines = {}
	local record = ns.Model.Specimen(ns.GetCharacterState(false), species.id)
	local function AddLine(line)
		if #lines < 3 then
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
		if #lines >= 3 then
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

---@param species FGSpecies?
---@param character FGState? the character's saved state, not one species' entry
---@param zone FGZone?
function Detail.Show(species, character, zone)
	if not species or not zone then
		modelSpecies = nil
		currentMap = nil
		Detail.model:ClearModel()
		Detail.model:Hide()
		Detail.portrait:Hide()
		Detail.modelNotice:Hide()
		Detail.location:Hide()
		Detail.locationName:SetText("")
		Detail.mapButton:Disable()
		Detail.mapButton:Hide()
		Detail.researchCard:Hide()
		for _, page in ipairs(Detail.pages) do
			page:Hide()
		end
		for _, button in ipairs(Detail.tabs) do
			button:Hide()
		end
		Detail.name:SetText(L["Select a creature to read its entry."])
		Detail.sub:SetText("")
		for _, badge in ipairs(Detail.badges) do
			badge.frame:Hide()
		end
		Detail.sightingText:SetText("")
		return
	end
	Detail.model:Show()
	Detail.location:Show()
	Detail.researchCard:Show()
	for _, button in ipairs(Detail.tabs) do
		button:Show()
	end
	Detail.SetPage(selectedPage)
	if modelSpecies ~= species.id then
		Detail.model:ClearModel()
		modelSpecies = species.id
		Art.Icon(Detail.portrait, Art.SpeciesIcon(species.name, species.id), 96)
		Detail.portrait:Show()
		Detail.modelNotice:Show()
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
	UpdateBadges(species, character)
	UpdateResearch(state)
	UpdateVariants(character, species)
	UpdateRewards(state)
	UpdateSightings(species, zone)
end
