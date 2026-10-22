---@type string, FGNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class FGWindow
local Window = {}
ns.Window = Window

local WIDTH, HEIGHT = 960, 720
local LEFT_WIDTH = 396
local PANEL_HEIGHT = 494

---@type Frame?
local frame
---@type integer?
local selectedId
local tab = "creatures"
local filter = "all"
local query = ""
local zoneIndex = 1

local tabs = {
	{ key = "creatures", text = "CREATURES" },
	{ key = "rares", text = "RARES" },
	{ key = "shiny", text = "SHINY" },
	{ key = "instances", text = "INSTANCES" },
}

local filters = {
	{ key = "all", text = "All" },
	{ key = "discovered", text = "Discovered" },
	{ key = "undiscovered", text = "Undiscovered" },
	{ key = "mastered", text = "Mastered" },
	{ key = "rare", text = "Rare species" },
	{ key = "shiny", text = "Shiny seen" },
}

---@return FGZone
local function CurrentZone()
	return (ns.Zones or {})[zoneIndex] or (ns.Zones or {})[1]
end

---@param parent Frame
---@param text string
---@param width number
---@param solid? boolean
---@return Frame
local function MakeButton(parent, text, width, solid)
	-- The client's own button, so hover, press and disabled states are the ones players already know.
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 26)
	button:SetText(text)
	button.Label = button:GetFontString()
	if solid then
		local r, g, b = Art.RGBA("gold", 1)
		button.Label:SetTextColor(r, g, b, 1)
	end
	return button
end

---@param parent Frame
---@param key string
---@param text string
---@param previous Frame?
---@return Frame
local function MakeTab(parent, key, text, previous)
	-- PanelTabButtonTemplate: the paper tabs the client uses on its own panels, with the selected art and the
	-- white/gold text shift handled by PanelTemplates.
	local button = CreateFrame("Button", nil, parent, "PanelTabButtonTemplate")
	if previous then
		button:SetPoint("TOPLEFT", previous, "TOPRIGHT", 4, 0)
	else
		button:SetPoint("TOPLEFT", 24, -58)
	end
	button:SetText(L[text])
	PanelTemplates_TabResize(button, 0)
	button.key = key
	button:SetScript("OnClick", function()
		Window.SetTab(key)
	end)
	return button
end

---@param parent Frame
local function BuildHeader(parent)
	-- The template's own portrait and title; the addon only names them.
	if parent.PortraitContainer and parent.PortraitContainer.Portrait then
		parent.PortraitContainer.Portrait:SetTexture(Art.BOOK_ICON)
	end
	if parent.TitleContainer and parent.TitleContainer.TitleText then
		parent.TitleContainer.TitleText:SetText(L["FIELD GUIDE"])
	end
	if parent.CloseButton then
		parent.CloseButton:SetScript("OnClick", function()
			Window.Hide()
		end)
	end

	local subtitle = Art.Text(parent, "GameFontDisableSmall", "muted")
	subtitle:SetPoint("TOP", 0, -28)
	subtitle:SetText(L["Azeroth field journal"])

	local headerLine = Art.Line(parent, "border", 0.5)
	headerLine:SetPoint("TOPLEFT", 18, -52)
	headerLine:SetPoint("TOPRIGHT", -18, -52)

	Window.tabButtons = {}
	for index, info in ipairs(tabs) do
		Window.tabButtons[index] = MakeTab(parent, info.key, info.text, Window.tabButtons[index - 1])
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
	filterButton:SetTextInsets(8, 8, 0, 0)
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
	breadcrumb.text:SetWidth(360)
	breadcrumb.arrow = breadcrumb:CreateTexture(nil, "ARTWORK")
	breadcrumb.arrow:SetAtlas("common-dropdown-c-button-hover-arrow")
	breadcrumb.arrow:SetSize(12, 5)
	breadcrumb.arrow:SetPoint("LEFT", breadcrumb.text, "RIGHT", 4, 0)
	Window.breadcrumb = breadcrumb
end

local zoneMenu
---@param parent Frame
local function BuildZoneMenu(parent)
	zoneMenu = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	zoneMenu:SetSize(260, #(ns.Zones or {}) * 22 + 8)
	zoneMenu:SetPoint("TOPLEFT", 24, -111)
	Art.Card(zoneMenu, "background", 0.98)
	zoneMenu:Hide()
	local scroll = 4
	for index, zone in ipairs(ns.Zones or {}) do
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

function Window.RebuildZoneMenu()
	if zoneMenu then
		zoneMenu:Hide()
	end
	if Window.frame then
		BuildZoneMenu(Window.frame)
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
	label:SetPoint("TOPLEFT", 14, -10)
	label:SetText(L["ZONE COMPLETION"])

	Window.progressText = Art.Text(bar, "GameFontNormal", "gold")
	Window.progressText:SetPoint("TOPLEFT", label, "TOPRIGHT", 8, 0)

	Window.progressCount = Art.Text(bar, "GameFontDisableSmall", "muted")
	Window.progressCount:SetPoint("TOPLEFT", 220, -10)
	Window.progressCount:SetWidth(140)
	Window.progressCount:SetJustifyH("RIGHT")

	local progress = Art.Bar(bar, 320, 10, "complete")
	progress:SetPoint("TOPLEFT", 14, -28)
	Window.progressFill = progress.Fill

	Window.openButton = MakeButton(bar, L["Open Journal"], 120, false)
	Window.openButton:SetPoint("TOPRIGHT", -140, -16)
	Window.openButton:SetScript("OnClick", function()
		Window.Show()
		Window.SetTab("creatures")
	end)

	Window.trackButton = MakeButton(bar, L["Track Species"], 120, true)
	Window.trackButton:SetPoint("TOPRIGHT", -12, -16)
	Window.trackButton:SetScript("OnClick", function()
		Window.ToggleTrack()
	end)
end

local function UpdateBreadcrumb()
	local zone = CurrentZone()
	Window.breadcrumb.text:SetText(zone and string.format(L["%s > %s"], L[zone.continent], L[zone.name]) or "")
end

local function UpdateTabs()
	for _, button in ipairs(Window.tabButtons or {}) do
		if button.key == tab then
			PanelTemplates_SelectTab(button)
		else
			PanelTemplates_DeselectTab(button)
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

---@param species FGSpecies
---@return boolean
local function MatchesFilter(species)
	local state = ns.GetCharacterState(false)
	local entry = state and state.species[species.id]
	local count = entry and entry.count or 0
	local options = ns.db and ns.db.options or {}
	if options.showUndiscovered == false and count == 0 and tab == "creatures" then
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

---@return FGListEntry[]
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
		for _, zone in ipairs(ns.Zones or {}) do
			for _, species in ipairs(zone.species) do
				if species.rare then
					Add(species)
				end
			end
		end
	elseif tab == "shiny" then
		for _, zone in ipairs(ns.Zones or {}) do
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
	if not zone then
		return
	end
	local state = ns.GetCharacterState(false)
	local progress = ns.Model.ZoneProgress(state, zone.species)
	local percent = math.floor(progress.fraction * 100 + 0.5)
	Window.progressText:SetText(string.format(L["%d%%"], percent))
	Window.progressCount:SetText(string.format(L["%d of %d species"], progress.catalogued, progress.total))
	Window.progressFill:SetWidth(320 * progress.fraction)
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
	if ns.catalogueStatus ~= "ok" then
		for _, panel in ipairs(Window.creaturePanels or {}) do
			panel:Hide()
		end
		Window.instances:Hide()
		Window.catalogueNotice:Show()
		Window.catalogueNotice:SetText(
			ns.catalogueStatus == "loading" and L["Loading QuestieDB catalogue…"]
				or L["Install QuestieDB or Questie to load the creature catalogue.\nhttps://www.curseforge.com/wow/addons/questie"]
		)
		return
	end
	Window.catalogueNotice:Hide()
	if tab == "instances" then
		for _, panel in ipairs(Window.creaturePanels or {}) do
			panel:Hide()
		end
		Window.instances:Show()
		Window.breadcrumb:Hide()
		Window.search:Hide()
		Window.filterButton:Hide()
		Window.bottomBar:Hide()
		ns.InstancesView.Refresh(ns.Instances, ns.API.Encounters())
		UpdateTabs()
		return
	end
	for _, panel in ipairs(Window.creaturePanels or {}) do
		panel:Show()
	end
	Window.instances:Hide()
	Window.breadcrumb:Show()
	Window.search:Show()
	Window.filterButton:Show()
	Window.bottomBar:Show()
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
	for index, entry in ipairs(ns.Zones or {}) do
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
	-- PortraitFrameTemplate supplies the metal NineSlice, the circular portrait bezel, the title and the close
	-- button, so the journal sits in the client's own window rather than an addon-drawn rectangle.
	frame = CreateFrame("Frame", "FieldGuideForeverFrame", UIParent, "PortraitFrameTemplate,BackdropTemplate")
	Window.frame = frame
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:Hide()
	-- PortraitFrameTemplate is only the chrome; the journal supplies its own opaque Bg so the world never shows
	-- through the list.
	frame.Bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.Bg:SetAllPoints(frame)
	frame.Bg:SetColorTexture(Art.RGBA("background", 0.98))

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
	Window.catalogueNotice = Art.Text(frame, "GameFontNormalLarge", "text")
	Window.catalogueNotice:SetPoint("CENTER", frame, "CENTER", 0, -12)
	Window.catalogueNotice:SetWidth(680)
	Window.catalogueNotice:SetJustifyH("CENTER")

	local left = CreateFrame("Frame", nil, frame)
	left:SetPoint("TOPLEFT", 18, -146)
	left:SetSize(LEFT_WIDTH, PANEL_HEIGHT)
	local right = CreateFrame("Frame", nil, frame)
	right:SetPoint("TOPLEFT", 426, -146)
	right:SetSize(516, PANEL_HEIGHT)

	ns.List.Create(left, { Select = Window.SelectSpecies })
	ns.Detail.Create(right)
	Window.creaturePanels = { left, right }
	Window.instances = ns.InstancesView.Create(frame)

	if type(UISpecialFrames) == "table" then
		local found = false
		for _, name in ipairs(UISpecialFrames) do
			if name == "FieldGuideForeverFrame" then
				found = true
				break
			end
		end
		if not found then
			table.insert(UISpecialFrames, "FieldGuideForeverFrame")
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
