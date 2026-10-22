---@type string, FGNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class FGDetail
local Detail = {}
ns.Detail = Detail

local CARD_WIDTH = 488
local PIPS = { "Discovered", "Observed", "Studied", "Mastered" }
local REWARDS = { "Field sketch", "Ink study", "Brass plate", "Gilded entry" }

---@param parent Frame
---@param x number
---@param y number
---@param width number
---@param height number
---@return Frame
local function Card(parent, x, y, width, height)
	local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	card:SetSize(width, height)
	Art.Card(card)
	return card
end

---@param parent Frame
---@return Frame
local function BuildBadges(parent)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetPoint("TOPLEFT", 14, -76)
	holder:SetSize(CARD_WIDTH, 18)
	Detail.badges = {}
	for index = 1, 4 do
		local badge = CreateFrame("Frame", nil, holder, "BackdropTemplate")
		badge:SetSize(60, 18)
		Art.Card(badge, "panel", 0.9)
		local text = Art.Text(badge, "GameFontDisableSmall", "text")
		text:SetPoint("CENTER")
		Detail.badges[index] = { frame = badge, text = text }
	end
	return holder
end

---@param parent Frame
local function BuildResearch(parent)
	local card = Card(parent, 14, -102, CARD_WIDTH, 84)
	Detail.researchCard = card
	local title = Art.Text(card, "GameFontNormal", "gold")
	title:SetPoint("TOPLEFT", 10, -7)
	title:SetText(L["Research"])

	Detail.pips = {}
	for index = 1, 4 do
		local x = 28 + (index - 1) * 112
		local dot = Art.Texture(card, "ARTWORK", "muted", 0.4)
		dot:SetSize(10, 10)
		dot:SetPoint("TOPLEFT", x, -28)
		local label = Art.Text(card, "GameFontDisableSmall", "muted")
		label:SetPoint("TOPLEFT", x - 39, -42)
		label:SetWidth(88)
		label:SetJustifyH("CENTER")
		label:SetText(L[PIPS[index]])
		local connector
		if index < 4 then
			connector = Art.Line(card, "panel", 1)
			connector:SetPoint("TOPLEFT", x + 13, -32)
			connector:SetWidth(112 - 26)
		end
		Detail.pips[index] = { dot = dot, label = label, connector = connector }
	end

	local specimenLabel = Art.Text(card, "GameFontDisableSmall", "muted")
	specimenLabel:SetPoint("TOPLEFT", 10, -60)
	specimenLabel:SetText(L["Mastery"])
	Detail.specimenCount = Art.Text(card, "GameFontDisableSmall", "text")
	Detail.specimenCount:SetPoint("TOPRIGHT", -10, -60)
	local bar = Art.Bar(card, CARD_WIDTH - 20, 4, "gold")
	bar:SetPoint("TOPLEFT", 10, -74)
	Detail.specimenBar = bar.Fill
end

---@param parent Frame
local function BuildLore(parent)
	local card = Card(parent, 14, -196, CARD_WIDTH, 58)
	Detail.loreCard = card
	local title = Art.Text(card, "GameFontNormal", "gold")
	title:SetPoint("TOPLEFT", 10, -7)
	title:SetText(L["Lore"])
	local lore = Art.Text(card, "GameFontDisableSmall", "text")
	lore:SetPoint("TOPLEFT", 10, -21)
	lore:SetWidth(CARD_WIDTH - 20)
	lore:SetJustifyH("LEFT")
	lore:SetWordWrap(true)
	lore:SetSpacing(1)
	if lore.SetMaxLines then
		lore:SetMaxLines(2)
	end
	Detail.lore = lore
end

---@param parent Frame
local function BuildVariants(parent)
	local title = Art.Text(parent, "GameFontNormal", "gold")
	title:SetPoint("TOPLEFT", 14, -264)
	title:SetText(L["Variants"])

	Detail.variants = {}
	for index = 1, 3 do
		local x = 14 + (index - 1) * 165
		local width = index == 3 and 158 or 157
		local card = Card(parent, x, -280, width, 52)
		local name = Art.Text(card, "GameFontNormal", "text")
		name:SetPoint("TOPLEFT", 10, -7)
		local tick = card:CreateTexture(nil, "OVERLAY")
		tick:SetSize(12, 12)
		tick:SetPoint("TOPRIGHT", -10, -7)
		local dash = Art.Text(card, "GameFontNormal", "muted")
		dash:SetPoint("TOPRIGHT", -10, -7)
		dash:SetWidth(12)
		dash:SetJustifyH("CENTER")
		local status = Art.Text(card, "GameFontDisableSmall", "muted")
		status:SetPoint("TOPLEFT", 10, -29)
		Detail.variants[index] = { frame = card, name = name, tick = tick, dash = dash, status = status }
	end
	Detail.variants[1].name:SetText(L["Common"])
	Detail.variants[2].name:SetText(L["Rare variant"])
	Detail.variants[3].name:SetText(L["Shiny variant"])
end

---@param parent Frame
local function BuildRewards(parent)
	local card = Card(parent, 14, -342, CARD_WIDTH, 66)
	Detail.rewardsCard = card
	local title = Art.Text(card, "GameFontNormal", "gold")
	title:SetPoint("TOPLEFT", 10, -7)
	title:SetText(L["Cosmetic rewards"])
	Detail.rewards = {}
	for index = 1, 4 do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local label = Art.Text(card, "GameFontDisableSmall", "text")
		local columnX = column == 0 and 10 or 258
		local columnRight = columnX + 224
		label:SetPoint("TOPLEFT", columnX, -28 - row * 20)
		label:SetWidth(120)
		label:SetText(L[REWARDS[index]])
		local status = Art.Text(card, "GameFontDisableSmall", "muted")
		status:SetPoint("TOPLEFT", columnRight - 86, -28 - row * 20)
		status:SetWidth(86)
		status:SetJustifyH("RIGHT")
		local marker = card:CreateTexture(nil, "OVERLAY")
		marker:SetSize(12, 12)
		marker:SetPoint("TOPLEFT", columnX + 126, -27 - row * 20)
		local dash = Art.Text(card, "GameFontNormal", "muted")
		dash:SetPoint("TOPLEFT", columnX + 126, -28 - row * 20)
		dash:SetWidth(12)
		dash:SetJustifyH("CENTER")
		Detail.rewards[index] = { label = label, status = status, marker = marker, dash = dash }
	end
end

---@param parent Frame
local function BuildSightings(parent)
	local card = Card(parent, 14, -418, CARD_WIDTH, 60)
	Detail.sightingCard = card
	local title = Art.Text(card, "GameFontNormal", "gold")
	title:SetPoint("TOPLEFT", 10, -7)
	title:SetText(L["Your records"])
	local text = Art.Text(card, "GameFontDisableSmall", "muted")
	text:SetPoint("TOPLEFT", 10, -21)
	text:SetWidth(CARD_WIDTH - 20)
	text:SetHeight(34)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetWordWrap(true)
	Detail.sightingText = text
end

---@param parent Frame
function Detail.Create(parent)
	Detail.parent = parent
	Detail.portrait = Art.Portrait(parent, 58)
	Detail.portrait:SetPoint("TOPLEFT", 14, -14)
	Art.Bezel(Detail.portrait)

	Detail.name = Art.Text(parent, "GameFontNormal", "text")
	Detail.name:SetPoint("TOPLEFT", 84, -18)
	Detail.name:SetWidth(380)

	Detail.sub = Art.Text(parent, "GameFontDisableSmall", "muted")
	Detail.sub:SetPoint("TOPLEFT", 84, -40)
	Detail.sub:SetWidth(380)

	BuildBadges(parent)
	BuildResearch(parent)
	BuildLore(parent)
	BuildVariants(parent)
	BuildRewards(parent)
	BuildSightings(parent)

	Detail.note = Art.Text(parent, "GameFontDisableSmall", "muted")
	Detail.note:SetPoint("BOTTOMLEFT", 14, 2)
	Detail.note:SetText(L["Cosmetic only — the field guide never grants player power."])
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
---@param state FGSpeciesState?
---@param zone FGZone
local function UpdateBadges(species, state)
	local variants = ns.Model.Variants(state, species.id)
	local labels = {
		{ key = "Common", color = "text", show = true },
		{ key = "Rare variant known", color = "rare", show = variants.rare.known },
		{ key = "Shiny seen", color = "shiny", show = variants.shiny.known },
		{ key = "Tracked", color = "complete", show = state and state.tracked == species.id },
	}
	local x = 0
	for index = 1, 4 do
		local badge = Detail.badges[index]
		local info = labels[index]
		if info.show then
			badge.text:SetText(L[info.key])
			local width = math.max(50, math.ceil(badge.text:GetStringWidth()) + 14)
			badge.frame:SetWidth(width)
			badge.frame:SetPoint("TOPLEFT", x, 0)
			local r, g, b = Art.RGBA(info.color, 1)
			badge.text:SetTextColor(r, g, b, 1)
			badge.frame:Show()
			x = x + width + 6
		else
			badge.frame:Hide()
		end
	end
end

---@param state FGSpeciesState?
---@param species FGSpecies
local function UpdateResearch(state)
	local count = state and state.count or 0
	local rank = ns.Model.Rank(count)
	for index = 1, 4 do
		local pip = Detail.pips[index]
		local active = rank >= index
		local r, g, b = Art.RGBA(active and "gold" or "muted", active and 1 or 0.4)
		pip.dot:SetVertexColor(r, g, b, 1)
		local lr, lg, lb = Art.RGBA(active and "text" or "muted", 1)
		pip.label:SetTextColor(lr, lg, lb, 1)
		if pip.connector then
			local cr, cg, cb = Art.RGBA(rank > index and "gold" or "panel", 1)
			pip.connector:SetVertexColor(cr, cg, cb, 1)
		end
	end
	local killCount = state and (state.kills or state.count) or 0
	local format = state and state.killsEstimated and "%d / %d · at least %d recorded deaths"
		or "%d / %d · %d recorded deaths"
	Detail.specimenCount:SetText(string.format(L[format], count, ns.Model.MASTERED_AT, killCount))
	Detail.specimenBar:SetWidth((CARD_WIDTH - 20) * count / ns.Model.MASTERED_AT)
	Detail.specimenBar:Show()
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
		SetLabelColor(card.dash, "—", "muted")
		card.status:SetText(string.format(L["%d / %d"], variant.count, variant.target))
	end
end

---@param state FGSpeciesState?
---@param species FGSpecies
local function UpdateVariants(state, species)
	local variants = ns.Model.Variants(state, species.id)
	UpdateVariant(Detail.variants[1], variants.common, "complete", L["Known"])
	UpdateVariant(Detail.variants[2], variants.rare, "rare", L["Known"])
	UpdateVariant(Detail.variants[3], variants.shiny, "gold", L["Known"])
end

---@param state FGSpeciesState?
local function UpdateRewards(state)
	local rank = ns.Model.Rank(state and state.count or 0)
	for index = 1, 4 do
		local row = Detail.rewards[index]
		if rank >= index then
			row.status:SetText(L["UNLOCKED"])
			row.marker:SetAtlas("common-icon-checkmark")
			row.marker:SetVertexColor(Art.RGBA("complete", 1))
			row.dash:SetText("")
			local r, g, b = Art.RGBA("complete", 1)
			row.status:SetTextColor(r, g, b, 1)
		else
			row.status:SetText(string.format(L["Locked · %s"], L[PIPS[index]]))
			row.marker:SetTexture(nil)
			row.dash:SetText(L["—"])
			local mr, mg, mb = Art.RGBA("muted", 1)
			row.dash:SetTextColor(mr, mg, mb, 1)
			local r, g, b = Art.RGBA("muted", 1)
			row.status:SetTextColor(r, g, b, 1)
		end
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
---@param state FGSpeciesState?
---@param zone FGZone?
function Detail.Show(species, state, zone)
	if not species or not zone then
		Detail.name:SetText(L["Select a creature to read its entry."])
		Detail.sub:SetText("")
		Art.Icon(Detail.portrait, "Interface\\Icons\\INV_Misc_QuestionMark", 58)
		for _, badge in ipairs(Detail.badges) do
			badge.frame:Hide()
		end
		Detail.lore:SetText("")
		Detail.sightingText:SetText("")
		return
	end
	Art.Icon(Detail.portrait, Art.SpeciesIcon(species.name, species.id), 58)
	Detail.name:SetText(species.name)
	Detail.sub:SetText(
		string.format(
			L["%s · %s · Level %s"],
			L[species.family],
			L[zone.name],
			ns.Model.LevelRange(species.minLevel, species.maxLevel)
		)
	)
	Detail.lore:SetText(string.format(L['"%s"'], species.lore))
	UpdateBadges(species, state)
	UpdateResearch(state)
	UpdateVariants(state, species)
	UpdateRewards(state)
	UpdateSightings(species, zone)
end
