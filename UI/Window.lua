---@type string, BFNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class BFWindow
local Window = {}
ns.Window = Window

local WIDTH, HEIGHT = 960, 720
local LEFT_WIDTH = 396
local PANEL_HEIGHT = 494

---@type Frame?
local frame
---@type integer?
local selectedId
local tab = "bestiary"
local filter = "all"
local query = ""
local zoneIndex = 1

local tabs = {
	{ key = "bestiary", text = "BESTIARY" },
	{ key = "rares", text = "RARES" },
	{ key = "shiny", text = "SHINY" },
}

local filters = {
	{ key = "all", text = "All" },
	{ key = "discovered", text = "Discovered" },
	{ key = "undiscovered", text = "Undiscovered" },
	{ key = "mastered", text = "Mastered" },
	{ key = "rare", text = "Rare species" },
	{ key = "shiny", text = "Shiny seen" },
}

---@return BFZone
local function CurrentZone()
	return ns.Creatures.zones[zoneIndex] or ns.Creatures.zones[1]
end

---@param parent Frame
---@param text string
---@param width number
---@param solid? boolean
---@return Frame
local function MakeButton(parent, text, width, solid)
	local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
	button:SetSize(width, 26)
	Art.Card(button, solid and "gold" or "panel", 1)
	local label = Art.Text(button, "GameFontNormal", solid and "background" or "text")
	label:SetPoint("CENTER")
	label:SetText(text)
	button.Label = label
	button:SetScript("OnEnter", function()
		label:SetAlpha(0.75)
	end)
	button:SetScript("OnLeave", function()
		label:SetAlpha(1)
	end)
	return button
end

---@param parent Frame
---@param key string
---@param text string
---@param x number
---@return Frame
local function MakeTab(parent, key, text, x)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(108, 26)
	button:SetPoint("TOPLEFT", x, -56)
	button.dot = Art.Texture(button, "ARTWORK", "gold", 1)
	button.dot:SetSize(6, 6)
	button.dot:SetPoint("LEFT", 4, 0)
	button.dot:Hide()
	button.label = Art.Text(button, "GameFontNormal", "muted")
	button.label:SetPoint("LEFT", 16, 0)
	button.label:SetText(L[text])
	button.key = key
	button:SetScript("OnClick", function()
		Window.SetTab(key)
	end)
	return button
end

---@param parent Frame
local function BuildHeader(parent)
	local medallion = Art.Portrait(parent, 44)
	medallion:SetPoint("TOPLEFT", 18, -12)
	medallion:SetTexture("Interface\\Icons\\INV_Misc_Book_09")

	local title = Art.Text(parent, "GameFontNormal", "gold")
	title:SetPoint("TOPLEFT", 74, -14)
	title:SetText(L["BESTIARY"])
	title:SetScale(1.2)

	local subtitle = Art.Text(parent, "GameFontDisableSmall", "muted")
	subtitle:SetPoint("TOPLEFT", 74, -32)
	subtitle:SetText(L["Azeroth field journal"])

	local close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function()
		Window.Hide()
	end)

	local headerLine = Art.Line(parent, "border", 0.5)
	headerLine:SetPoint("TOPLEFT", 18, -52)
	headerLine:SetPoint("TOPRIGHT", -18, -52)

	Window.tabButtons = {}
	for index, info in ipairs(tabs) do
		Window.tabButtons[index] = MakeTab(parent, info.key, info.text, 20 + (index - 1) * 116)
	end
end

---@param parent Frame
local function BuildSearch(parent)
	local search = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	search:SetSize(250, 24)
	search:SetPoint("TOPLEFT", 24, -112)
	search:SetAutoFocus(false)
	search:SetMaxLetters(40)
	search:SetFontObject(GameFontHighlight)
	search:SetTextInsets(8, 8, 0, 0)
	Window.search = search

	local placeholder = Art.Text(search, "GameFontDisableSmall", "muted")
	placeholder:SetPoint("LEFT", 8, 1)
	placeholder:SetText(L["Search creatures"])
	Window.searchPlaceholder = placeholder

	search:SetScript("OnTextChanged", function(self)
		query = self:GetText() or ""
		placeholder:SetShown(query == "")
		Window.Refresh()
	end)
	search:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	local filterButton = MakeButton(parent, L["All"], 128, false)
	filterButton:SetPoint("TOPLEFT", 288, -112)
	filterButton:SetHeight(24)
	Window.filterButton = filterButton
	filterButton:SetScript("OnClick", function()
		Window.ToggleFilterMenu()
	end)

	local divider = Art.Line(parent, "border", 0.4)
	divider:SetPoint("TOPLEFT", 18, -142)
	divider:SetPoint("TOPRIGHT", -18, -142)
end

---@param parent Frame
local function BuildBreadcrumb(parent)
	local breadcrumb = CreateFrame("Button", nil, parent)
	breadcrumb:SetSize(390, 20)
	breadcrumb:SetPoint("TOPLEFT", 24, -90)
	breadcrumb:SetScript("OnClick", function()
		Window.ToggleZoneMenu()
	end)
	breadcrumb.text = Art.Text(breadcrumb, "GameFontNormal", "text")
	breadcrumb.text:SetPoint("LEFT")
	Window.breadcrumb = breadcrumb
end

local zoneMenu
---@param parent Frame
local function BuildZoneMenu(parent)
	zoneMenu = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	zoneMenu:SetSize(260, #ns.Creatures.zones * 22 + 8)
	zoneMenu:SetPoint("TOPLEFT", 24, -111)
	Art.Card(zoneMenu, "background", 0.98)
	zoneMenu:Hide()
	local scroll = 4
	for index, zone in ipairs(ns.Creatures.zones) do
		local button = CreateFrame("Button", nil, zoneMenu)
		button:SetPoint("TOPLEFT", 4, -scroll)
		button:SetSize(252, 20)
		local text = Art.Text(button, "GameFontHighlightSmall", "text")
		text:SetPoint("LEFT", 6, 0)
		text:SetText(string.format(L["%s · %s"], L[zone.continent], L[zone.name]))
		button:SetScript("OnClick", function()
			Window.SelectZone(index)
		end)
		scroll = scroll + 22
	end
end

local filterMenu
---@param parent Frame
local function BuildFilterMenu(parent)
	filterMenu = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	filterMenu:SetSize(170, #filters * 22 + 8)
	filterMenu:SetPoint("TOPLEFT", 288, -137)
	Art.Card(filterMenu, "background", 0.98)
	filterMenu:Hide()
	for index, info in ipairs(filters) do
		local button = CreateFrame("Button", nil, filterMenu)
		button:SetPoint("TOPLEFT", 4, -4 - (index - 1) * 22)
		button:SetSize(162, 20)
		local text = Art.Text(button, "GameFontHighlightSmall", "text")
		text:SetPoint("LEFT", 6, 0)
		text:SetText(L[info.text])
		button:SetScript("OnClick", function()
			Window.SetFilter(info.key)
		end)
	end
end

---@param parent Frame
local function BuildBottom(parent)
	local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	bar:SetPoint("BOTTOMLEFT", 18, 12)
	bar:SetSize(924, 58)
	Art.Card(bar, "panel", 0.96)
	Window.bottomBar = bar

	local label = Art.Text(bar, "GameFontDisableSmall", "muted")
	label:SetPoint("TOPLEFT", 14, -8)
	label:SetText(L["ZONE COMPLETION"])

	Window.progressText = Art.Text(bar, "GameFontNormal", "gold")
	Window.progressText:SetPoint("TOPLEFT", 14, -23)

	local progress = Art.Bar(bar, 320, 6, "complete")
	progress:SetPoint("TOPLEFT", 120, -27)
	Window.progressFill = progress.Fill

	Window.progressCount = Art.Text(bar, "GameFontDisableSmall", "muted")
	Window.progressCount:SetPoint("TOPLEFT", 120, -38)

	Window.openButton = MakeButton(bar, L["Open Journal"], 112, false)
	Window.openButton:SetPoint("TOPRIGHT", -158, -16)
	Window.openButton:SetScript("OnClick", function()
		Window.Show()
		Window.SetTab("bestiary")
	end)

	Window.trackButton = MakeButton(bar, L["Track Species"], 132, true)
	Window.trackButton:SetPoint("TOPRIGHT", -12, -16)
	Window.trackButton:SetScript("OnClick", function()
		Window.ToggleTrack()
	end)
end

local function UpdateBreadcrumb()
	local zone = CurrentZone()
	Window.breadcrumb.text:SetText(string.format(L["%s > %s  ▾"], L[zone.continent], L[zone.name]))
end

local function UpdateTabs()
	for _, button in ipairs(Window.tabButtons or {}) do
		local active = button.key == tab
		button.dot:SetShown(active)
		if active then
			local r, g, b = Art.RGBA("gold", 1)
			button.label:SetTextColor(r, g, b, 1)
		else
			local r, g, b = Art.RGBA("muted", 1)
			button.label:SetTextColor(r, g, b, 1)
		end
	end
end

local function UpdateFilterButton()
	local label = L["All"]
	for _, info in ipairs(filters) do
		if info.key == filter then
			label = L[info.text]
			break
		end
	end
	Window.filterButton.Label:SetText(label)
end

---@param species BFSpecies
---@return boolean
local function MatchesFilter(species)
	local state = ns.GetCharacterState(false)
	local entry = state and state.species[species.id]
	local count = entry and entry.count or 0
	local options = ns.db and ns.db.options or {}
	if options.showUndiscovered == false and count == 0 and tab == "bestiary" then
		return false
	end
	if filter == "discovered" and count == 0 then
		return false
	elseif filter == "undiscovered" and count > 0 then
		return false
	elseif filter == "mastered" and count < ns.Model.MASTERED_AT then
		return false
	elseif filter == "rare" and not species.rare then
		return false
	elseif filter == "shiny" and (not entry or entry.shiny < ns.Model.SHINY_TARGET) then
		return false
	end
	if query ~= "" then
		local needle = query:lower()
		if not species.name:lower():find(needle, 1, true) and not species.family:lower():find(needle, 1, true) then
			return false
		end
	end
	return true
end

---@return BFListEntry[]
local function BuildEntries()
	local state = ns.GetCharacterState(false)
	local entries = {}
	local function Add(species)
		if MatchesFilter(species) then
			entries[#entries + 1] = {
				species = species,
				state = state and state.species[species.id] or nil,
				zone = ns.SpeciesZone[species.id],
			}
		end
	end
	if tab == "rares" then
		for _, zone in ipairs(ns.Creatures.zones) do
			for _, species in ipairs(zone.species) do
				if species.rare then
					Add(species)
				end
			end
		end
	elseif tab == "shiny" then
		for _, zone in ipairs(ns.Creatures.zones) do
			for _, species in ipairs(zone.species) do
				local row = state and state.species[species.id]
				if row and row.shiny >= ns.Model.SHINY_TARGET then
					Add(species)
				end
			end
		end
	else
		for _, species in ipairs(CurrentZone().species) do
			Add(species)
		end
	end
	return entries
end

local function UpdateProgress()
	local zone = CurrentZone()
	local state = ns.GetCharacterState(false)
	local progress = ns.Model.ZoneProgress(state, zone.species)
	local percent = math.floor(progress.fraction * 100 + 0.5)
	Window.progressText:SetText(string.format(L["%d%%"], percent))
	Window.progressCount:SetText(string.format(L["%d of %d species"], progress.catalogued, progress.total))
	Window.progressFill:SetWidth(318 * progress.fraction)
end

local function UpdateTrackButton()
	local state = ns.GetCharacterState(false)
	local tracked = selectedId and state and state.tracked == selectedId
	Window.trackButton.Label:SetText(tracked and L["Tracking"] or L["Track Species"])
end

function Window.UpdateDetail()
	local zone = CurrentZone()
	local species = selectedId and ns.SpeciesById[selectedId] or nil
	local speciesZone = species and ns.SpeciesZone[species.id] or zone
	local state = ns.GetCharacterState(false)
	local entry = species and state and state.species[species.id] or nil
	ns.Detail.Show(species, entry, speciesZone)
	UpdateTrackButton()
end

function Window.Refresh()
	if not frame then
		return
	end
	local entries = BuildEntries()
	local stillListed = false
	for _, entry in ipairs(entries) do
		if entry.species.id == selectedId then
			stillListed = true
			break
		end
	end
	if not stillListed then
		selectedId = entries[1] and entries[1].species.id or nil
	end
	ns.List.Refresh(entries, selectedId)
	Window.UpdateDetail()
	UpdateProgress()
	UpdateBreadcrumb()
	UpdateTabs()
	UpdateFilterButton()
end

---@param key string
function Window.SetTab(key)
	tab = key
	Window.Refresh()
end

---@param key string
function Window.SetFilter(key)
	filter = key
	if filterMenu then
		filterMenu:Hide()
	end
	Window.Refresh()
end

---@param index integer
function Window.SelectZone(index)
	zoneIndex = index
	selectedId = nil
	if zoneMenu then
		zoneMenu:Hide()
	end
	Window.Refresh()
end

---@param speciesId integer
function Window.SelectSpecies(speciesId)
	selectedId = speciesId
	ns.List.SetSelected(speciesId)
	Window.UpdateDetail()
end

function Window.ToggleTrack()
	local state = ns.GetCharacterState(true)
	if not state or not selectedId then
		return
	end
	if state.tracked == selectedId then
		state.tracked = nil
	else
		state.tracked = selectedId
	end
	Window.Refresh()
end

function Window.ToggleZoneMenu()
	if not frame then
		return
	end
	if not zoneMenu then
		BuildZoneMenu(frame)
	end
	zoneMenu:SetShown(not zoneMenu:IsShown())
end

function Window.ToggleFilterMenu()
	if not frame then
		return
	end
	if not filterMenu then
		BuildFilterMenu(frame)
	end
	filterMenu:SetShown(not filterMenu:IsShown())
end

function Window.FollowPlayerZone()
	local zone = ns.CurrentZone()
	if not zone then
		return
	end
	for index, entry in ipairs(ns.Creatures.zones) do
		if entry == zone then
			zoneIndex = index
			Window.Refresh()
			return
		end
	end
end

local function SavePosition()
	if not frame or not ns.db then
		return
	end
	local point, _, _, x, y = frame:GetPoint(1)
	if point then
		ns.db.window = { point = point, x = x or 0, y = y or 0 }
	end
end

local function Create()
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", "BestiaryForeverFrame", UIParent, "BackdropTemplate")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:Hide()
	Art.Panel(frame)

	local position = ns.db and ns.db.window
	if position and position.point then
		frame:SetPoint(position.point, UIParent, position.point, position.x or 0, position.y or 0)
	else
		frame:SetPoint("CENTER")
	end

	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)

	BuildHeader(frame)
	BuildBreadcrumb(frame)
	BuildSearch(frame)
	BuildBottom(frame)

	local left = CreateFrame("Frame", nil, frame)
	left:SetPoint("TOPLEFT", 18, -146)
	left:SetSize(LEFT_WIDTH, PANEL_HEIGHT)
	local right = CreateFrame("Frame", nil, frame)
	right:SetPoint("TOPLEFT", 426, -146)
	right:SetSize(516, PANEL_HEIGHT)

	ns.List.Create(left, { Select = Window.SelectSpecies })
	ns.Detail.Create(right)

	if type(UISpecialFrames) == "table" then
		local found = false
		for _, name in ipairs(UISpecialFrames) do
			if name == "BestiaryForeverFrame" then
				found = true
				break
			end
		end
		if not found then
			table.insert(UISpecialFrames, "BestiaryForeverFrame")
		end
	end

	Window.FollowPlayerZone()
	return frame
end

function Window.Show()
	Create()
	frame:Show()
	Window.Refresh()
end

function Window.Hide()
	if frame then
		frame:Hide()
	end
end

function Window.Toggle()
	if frame and frame:IsShown() then
		Window.Hide()
	else
		Window.Show()
	end
end

function Window.IsShown()
	return frame ~= nil and frame:IsShown()
end

-- A kill handler only writes tables. Refresh on the next frame instead of touching a frame from that handler, which
-- keeps the combat path free of anything a secure frame could make expensive or blocked.
local refreshPending = false
ns.OnProgress(function()
	if refreshPending then
		return
	end
	refreshPending = true
	C_Timer.After(0, function()
		refreshPending = false
		if Window.IsShown() then
			Window.Refresh()
		end
	end)
end)

ns.On("ZONE_CHANGED_NEW_AREA", function()
	if Window.IsShown() then
		Window.FollowPlayerZone()
	end
end)
