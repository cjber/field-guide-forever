---@type string, BFNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class BFDetail
local Detail = {}
ns.Detail = Detail

local CARD_WIDTH = 468
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
		local x = 28 + (index - 1) * 108
		local dot = Art.Texture(card, "ARTWORK", "muted", 0.4)
		dot:SetSize(10, 10)
		dot:SetPoint("TOPLEFT", x, -28)
		local label = Art.Text(card, "GameFontDisableSmall", "muted")
		label:SetPoint("TOPLEFT", x - 38, -42)
		label:SetWidth(86)
		label:SetJustifyH("CENTER")
		label:SetText(L[PIPS[index]])
		local connector = Art.Line(card, "panel", 1)
		connector:SetPoint("TOPLEFT", x + 13, -32)
		connector:SetWidth(106 - 16)
		Detail.pips[index] = { dot = dot, label = label, connector = connector }
	end

	local specimenLabel = Art.Text(card, "GameFontDisableSmall", "muted")
	specimenLabel:SetPoint("TOPLEFT", 10, -60)
	specimenLabel:SetText(L["Specimens"])
	Detail.specimenCount = Art.Text(card, "GameFontDisableSmall", "text")
	Detail.specimenCount:SetPoint("TOPRIGHT", -10, -60)
	local bar = Art.Bar(card, CARD_WIDTH - 20, 4, "gold")
	bar:SetPoint("TOPLEFT", 10, -74)
	Detail.specimenBar = bar.Fill
end

---@param parent Frame
local function BuildLore(parent)
	local card = Card(parent, 14, -192, CARD_WIDTH, 50)
	Detail.loreCard = card
	local title = Art.Text(card, "GameFontNormal", "gold")
	title:SetPoint("TOPLEFT", 10, -6)
	title:SetText(L["Lore"])
	local lore = Art.Text(card, "GameFontDisableSmall", "text")
	lore:SetPoint("TOPLEFT", 10, -20)
	lore:SetWidth(CARD_WIDTH - 20)
	lore:SetJustifyH("LEFT")
	lore:SetWordWrap(true)
	lore:SetSpacing(1)
	Detail.lore = lore
end

---@param parent Frame
local function BuildVariants(parent)
	local title = Art.Text(parent, "GameFontNormal", "gold")
	title:SetPoint("TOPLEFT", 14, -246)
	title:SetText(L["Variants"])

	Detail.variants = {}
	for index = 1, 3 do
		local card = Card(parent, 14 + (index - 1) * 156, -262, 148, 52)
		local name = Art.Text(card, "GameFontNormal", "text")
		name:SetPoint("TOPLEFT", 8, -6)
		local tick = Art.Text(card, "GameFontNormal", "muted")
		tick:SetPoint("TOPRIGHT", -8, -6)
		local status = Art.Text(card, "GameFontDisableSmall", "muted")
		status:SetPoint("TOPLEFT", 8, -28)
		Detail.variants[index] = { frame = card, name = name, tick = tick, status = status }
	end
	Detail.variants[1].name:SetText(L["Common"])
	Detail.variants[2].name:SetText(L["Rare variant"])
	Detail.variants[3].name:SetText(L["Shiny variant"])
end

---@param parent Frame
local function BuildRewards(parent)
	local card = Card(parent, 14, -320, CARD_WIDTH, 66)
	Detail.rewardsCard = card
	local title = Art.Text(card, "GameFontNormal", "gold")
	title:SetPoint("TOPLEFT", 10, -6)
	title:SetText(L["Cosmetic rewards"])
	Detail.rewards = {}
	for index = 1, 4 do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local label = Art.Text(card, "GameFontDisableSmall", "text")
		label:SetPoint("TOPLEFT", 10 + column * 230, -25 - row * 20)
		label:SetWidth(112)
		label:SetText(L[REWARDS[index]])
		local status = Art.Text(card, "GameFontDisableSmall", "muted")
		status:SetPoint("TOPLEFT", 126 + column * 230, -25 - row * 20)
		status:SetWidth(96)
		Detail.rewards[index] = { label = label, status = status }
	end
end

---@param parent Frame
local function BuildSightings(parent)
	local card = Card(parent, 14, -394, CARD_WIDTH, 76)
	Detail.sightingCard = card
	local title = Art.Text(card, "GameFontNormal", "gold")
	title:SetPoint("TOPLEFT", 10, -6)
	title:SetText(L["Sighting log"])
	local text = Art.Text(card, "GameFontDisableSmall", "muted")
	text:SetPoint("TOPLEFT", 10, -21)
	text:SetWidth(CARD_WIDTH - 20)
	text:SetHeight(48)
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
	Detail.note:SetPoint("BOTTOMRIGHT", -14, 4)
	Detail.note:SetText(L["Cosmetic only — the bestiary never grants player power."])
end

---@param text FontString
---@param key string
---@param color string
local function SetLabelColor(text, key, color)
	text:SetText(L[key])
	local r, g, b = Art.RGBA(color, 1)
	text:SetTextColor(r, g, b, 1)
end

---@param species BFSpecies
---@param state BFSpeciesState?
---@param zone BFZone
local function UpdateBadges(species, state)
	local variants = ns.Model.Variants(state, species.id)
	local labels = {
		{ key = "Common", color = "text", show = true },
		{ key = "★ Rare variant known", color = "rare", show = variants.rare.known },
		{ key = "✦ Shiny seen", color = "shiny", show = variants.shiny.known },
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

---@param state BFSpeciesState?
---@param species BFSpecies
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
	Detail.specimenCount:SetText(string.format(L["%d / %d"], count, ns.Model.MASTERED_AT))
	Detail.specimenBar:SetWidth((CARD_WIDTH - 20) * count / ns.Model.MASTERED_AT)
	Detail.specimenBar:Show()
end

---@param card table
---@param variant BFVariant
---@param color string
---@param knownText string
local function UpdateVariant(card, variant, color, knownText)
	if variant.known then
		card.tick:SetText(L["✓"])
		SetLabelColor(card.tick, "✓", color)
		card.status:SetText(knownText)
	else
		card.tick:SetText(L["—"])
		SetLabelColor(card.tick, "—", "muted")
		card.status:SetText(string.format(L["%d / %d"], variant.count, variant.target))
	end
end

---@param state BFSpeciesState?
---@param species BFSpecies
local function UpdateVariants(state, species)
	local variants = ns.Model.Variants(state, species.id)
	UpdateVariant(Detail.variants[1], variants.common, "complete", L["Known"])
	UpdateVariant(Detail.variants[2], variants.rare, "rare", L["Known"])
	UpdateVariant(Detail.variants[3], variants.shiny, "gold", L["Known"])
end

---@param state BFSpeciesState?
local function UpdateRewards(state)
	local rank = ns.Model.Rank(state and state.count or 0)
	for index = 1, 4 do
		local row = Detail.rewards[index]
		if rank >= index then
			row.status:SetText(L["UNLOCKED"])
			local r, g, b = Art.RGBA("complete", 1)
			row.status:SetTextColor(r, g, b, 1)
		else
			row.status:SetText(string.format(L["Locked · %s"], L[PIPS[index]]))
			local r, g, b = Art.RGBA("muted", 1)
			row.status:SetTextColor(r, g, b, 1)
		end
	end
end

---@param species BFSpecies
---@param zone BFZone
local function UpdateSightings(species, zone)
	local options = ns.db and ns.db.options or {}
	local showLog = options.showSightingLog ~= false
	Detail.sightingCard:SetShown(showLog)
	if not showLog then
		return
	end
	local lines = {}
	for _, entry in ipairs(ns.Model.GetSightings()) do
		if entry.species == species.name and entry.zone == zone.name then
			local stamp = date and date("%H:%M", entry.time) or tostring(entry.time)
			local kind = L["Kill"]
			if entry.kind == "rare" then
				kind = L["Rare"]
			elseif entry.kind == "shiny" then
				kind = L["Shiny"]
			end
			lines[#lines + 1] = string.format(L["%s · %s · %s"], stamp, L[entry.zone] or entry.zone, kind)
			if #lines >= 4 then
				break
			end
		end
	end
	if #lines == 0 then
		Detail.sightingText:SetText(L["No sightings yet this session."])
	else
		Detail.sightingText:SetText(table.concat(lines, "\n"))
	end
end

---@param species BFSpecies?
---@param state BFSpeciesState?
---@param zone BFZone?
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
	Art.Icon(Detail.portrait, Art.FamilyIcon(species.family), 58)
	Detail.name:SetText(species.name)
	Detail.sub:SetText(
		string.format(L["%s · %s · Level %d-%d"], L[species.family], L[zone.name], species.minLevel, species.maxLevel)
	)
	Detail.lore:SetText(string.format(L['"%s"'], species.lore))
	UpdateBadges(species, state)
	UpdateResearch(state)
	UpdateVariants(state, species)
	UpdateRewards(state)
	UpdateSightings(species, zone)
end
