---@type string, FGNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class FGWindow
local Window = {}
ns.Window = Window

local WIDTH, HEIGHT = 960, 700
local LEFT_WIDTH = 330
local PANEL_HEIGHT = 514
local FRAME_NAME = "FieldGuideForeverFrame"

-- A UI panel like the Adventure Guide: the game places it on the left, slides it beside other panels, and closes it
-- with Escape or when another left panel opens. Registered at load, before anything can show it. The special frames
-- entry closes it with Escape when it was opened in combat, outside the manager.
-- Blizzard reads UIPanelWindows only by a frame's name and never walks it, so the addon's entry taints nothing else.
local PANEL = { area = "left", pushable = 0, whileDead = 1, width = WIDTH }
if type(UIPanelWindows) == "table" then
	UIPanelWindows[FRAME_NAME] = PANEL -- taint-ok: an entry read only for this addon's own frame
end
if type(UISpecialFrames) == "table" then
	table.insert(UISpecialFrames, FRAME_NAME)
end

---@type FGWindowFrame?
local frame
---@type integer?
local selectedId
local tab = "creatures"
local filter = "all"
local query = ""
local zoneIndex = 1

local tabs = {
	{ key = "creatures", text = "CREATURES", icon = "Interface\\Icons\\INV_Misc_Book_09" },
	{ key = "rares", text = "RARES", icon = "Interface\\Icons\\INV_Misc_Spyglass_02" },
	{ key = "shiny", text = "SHINY", icon = "Interface\\Icons\\INV_Scroll_03" },
	{ key = "instances", text = "INSTANCES", icon = "Interface\\Icons\\INV_Chest_Chain_05" },
}

local filters = {
	{ key = "all", text = "All" },
	{ key = "discovered", text = "Discovered" },
	{ key = "undiscovered", text = "Undiscovered" },
	{ key = "mastered", text = "Mastered" },
	{ key = "rare", text = "Rare species" },
	{ key = "shiny", text = "Shiny seen" },
	{ key = "missingShiny", text = "Missing shiny" },
	{ key = "missingRare", text = "Missing rare" },
}

---@return FGZone
local function CurrentZone()
	return (ns.Zones or {})[zoneIndex] or (ns.Zones or {})[1]
end

---@param parent Frame
---@param text string
---@param width number
---@param solid? boolean
---@return FGButton
local function MakeButton(parent, text, width, solid)
	-- The client's own button, so hover, press and disabled states are the ones players already know.
	local button = CreateFrame("Button", nil, parent, "SharedButtonSmallTemplate") --[[@as FGButton]]
	button:SetSize(width, 26)
	button:SetText(text)
	button.Label = button:GetFontString()
	if solid then
		local r, g, b = Art.RGBA("gold", 1)
		button.Label:SetTextColor(r, g, b, 1)
	end
	return button
end

---@param parent FGWindowFrame
local function BuildHeader(parent)
	-- The template's own portrait and title; the addon only names them.
	if parent.PortraitContainer and parent.PortraitContainer.portrait then
		parent.PortraitContainer.portrait:SetTexture(Art.BOOK_ICON)
	end
	if parent.TitleContainer and parent.TitleContainer.TitleText then
		parent.TitleContainer.TitleText:SetText(L["Field Guide"])
	end

	Window.tabButtons = {}
	for index, info in ipairs(tabs) do
		local button = CreateFrame("Frame", nil, parent, "LargeSideTabButtonTemplate") --[[@as FGTabButton]]
		button:SetSize(55, 55)
		button.Icon:SetTexture(info.icon)
		button:SetFillToInterior(true)
		button.tooltipText = L[info.text]
		button:EnableMouse(true)
		button.key = info.key
		if index == 1 then
			button:SetPoint("TOPLEFT", parent, "TOPRIGHT", 3, -28)
		else
			button:SetPoint("TOPLEFT", Window.tabButtons[index - 1], "BOTTOMLEFT", 0, -3)
		end
		button:SetCustomOnMouseUpHandler(function(_, mouseButton, upInside)
			if mouseButton == "LeftButton" and upInside then
				Window.SetTab(info.key)
			end
		end)
		Window.tabButtons[index] = button
	end
end

---@param parent Frame
local function BuildSearch(parent)
	local search = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	search:SetSize(250, 24)
	search:SetPoint("TOPLEFT", 24, -62)
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
	filterButton:SetPoint("TOPLEFT", 288, -62)
	filterButton:SetHeight(24)
	Window.filterButton = filterButton
	filterButton:SetScript("OnClick", function()
		Window.ToggleFilterMenu()
	end)

	-- What is collected: this zone on the first line, every zone on the second.
	Window.totals = {}
	for index, labelKey in ipairs({ "zone", "all" }) do
		local values = Art.Text(parent, index == 1 and "GameFontHighlightSmall" or "GameFontDisableSmall", "text")
		values:SetPoint("TOPRIGHT", -24, -30 - (index - 1) * 18)
		values:SetJustifyH("RIGHT")
		local label = Art.Text(parent, index == 1 and "GameFontNormalSmall" or "GameFontDisableSmall", "gold")
		label:SetPoint("RIGHT", values, "LEFT", -10, 0)
		if index == 2 then
			label:SetTextColor(Art.RGBA("muted", 1))
			label:SetText(L["All zones"])
		end
		Window.totals[labelKey] = { label = label, values = values }
	end

	local divider = Art.Line(parent, "border", 0.4)
	divider:SetPoint("TOPLEFT", 18, -94)
	divider:SetPoint("TOPRIGHT", -18, -94)
end

---@param parent Frame
local function BuildBreadcrumb(parent)
	local breadcrumb = CreateFrame("Button", nil, parent)
	breadcrumb:SetSize(390, 20)
	-- Beside the portrait, where the Adventure Guide puts its navigation bar.
	breadcrumb:SetPoint("TOPLEFT", 64, -32)
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

---@param parent Frame
local function BuildBottom(parent)
	local bar = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	bar:SetPoint("BOTTOMLEFT", 18, 12)
	bar:SetSize(924, 58)
	Window.bottomBar = bar

	local label = Art.Text(bar, "GameFontNormal", "gold")
	label:SetPoint("TOPLEFT", 14, -10)
	label:SetText(L["Zone completion"])

	Window.progressText = Art.Text(bar, "GameFontNormal", "gold")
	Window.progressText:SetPoint("TOPLEFT", label, "TOPRIGHT", 8, 0)

	Window.progressCount = Art.Text(bar, "GameFontDisableSmall", "muted")
	Window.progressCount:SetPoint("TOPLEFT", 220, -10)
	Window.progressCount:SetWidth(140)
	Window.progressCount:SetJustifyH("RIGHT")

	Window.progressBar = Art.StatusBar(bar, 320, 12, 1)
	Window.progressBar:SetPoint("TOPLEFT", 14, -30)

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
		button:SetChecked(button.key == tab)
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
	elseif filter == "missingShiny" and entry and entry.shiny >= ns.Model.SHINY_TARGET then
		return false
	elseif
		filter == "missingRare"
		and (not ns.Model.HasRareForm(state, species) or (entry and entry.rare >= ns.Model.RARE_TARGET))
	then
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
	Window.progressBar:SetValue(progress.fraction)

	local everywhere = {}
	for _, species in pairs(ns.SpeciesById or {}) do
		everywhere[#everywhere + 1] = species
	end
	for key, list in pairs({ zone = zone.species, all = everywhere }) do
		local totals = ns.Model.VariantTotals(state, list)
		Window.totals[key].values:SetText(
			string.format(
				L["Rare %d / %d · Shiny %d / %d"],
				totals.rare,
				totals.rareTotal,
				totals.shiny,
				totals.shinyTotal
			)
		)
	end
	Window.totals.zone.label:SetText(L[zone.name])
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
	ns.Detail.Show(species, ns.GetCharacterState(false), speciesZone)
	UpdateTrackButton()
end

---@param preserveScroll boolean?
function Window.Refresh(preserveScroll)
	if not frame then
		return
	end
	UpdateTabs()
	if ns.catalogueStatus ~= "ok" then
		for _, panel in ipairs(Window.creaturePanels or {}) do
			panel:Hide()
		end
		for _, button in ipairs(Window.tabButtons or {}) do
			button:Hide()
		end
		Window.instances:Hide()
		Window.bottomBar:Hide()
		Window.breadcrumb:Hide()
		Window.search:Hide()
		Window.searchPlaceholder:Hide()
		Window.filterButton:Hide()
		Window.catalogueNotice:Show()
		Window.catalogueNotice:SetText(
			ns.catalogueStatus == "loading" and L["Loading QuestieDB catalogue…"]
				or L["Install QuestieDB or Questie to load the creature catalogue.\nhttps://www.curseforge.com/wow/addons/questie"]
		)
		return
	end
	Window.catalogueNotice:Hide()
	for _, button in ipairs(Window.tabButtons or {}) do
		button:Show()
	end
	if tab == "instances" then
		for _, panel in ipairs(Window.creaturePanels or {}) do
			panel:Hide()
		end
		Window.instances:Show()
		Window.bottomBar:Hide()
		Window.breadcrumb:Hide()
		Window.search:Hide()
		Window.searchPlaceholder:Hide()
		Window.filterButton:Hide()
		ns.InstancesView.Refresh(ns.Instances, ns.API.Encounters())
		UpdateTabs()
		return
	end
	for _, panel in ipairs(Window.creaturePanels or {}) do
		panel:Show()
	end
	Window.instances:Hide()
	Window.bottomBar:Show()
	Window.breadcrumb:Show()
	Window.search:Show()
	Window.searchPlaceholder:SetShown(query == "")
	Window.filterButton:Show()
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
	ns.List.Refresh(entries, selectedId, preserveScroll)
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
	Window.Refresh()
end

---@param index integer
function Window.SelectZone(index)
	zoneIndex = index
	selectedId = nil
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
	Window.Refresh(true)
end

function Window.ToggleZoneMenu()
	if not frame or not Window.breadcrumb then
		return
	end
	MenuUtil.CreateContextMenu(Window.breadcrumb, function(_, root)
		root:CreateTitle(L["Choose a zone"])
		for index, zone in ipairs(ns.Zones or {}) do
			local zoneIndexAtBuild = index
			local label = string.format(L["%s · %s"], L[zone.continent], L[zone.name])
			root:CreateRadio(label, function()
				return zoneIndex == zoneIndexAtBuild
			end, function()
				Window.SelectZone(zoneIndexAtBuild)
			end)
		end
	end)
end

function Window.ToggleFilterMenu()
	if not frame or not Window.filterButton then
		return
	end
	MenuUtil.CreateContextMenu(Window.filterButton, function(_, root)
		root:CreateTitle(L["Filter species"])
		for _, info in ipairs(filters) do
			local key = info.key
			root:CreateRadio(L[info.text], function()
				return filter == key
			end, function()
				Window.SetFilter(key)
			end)
		end
	end)
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

---@return FGWindowFrame
local function Create()
	if frame then
		return frame
	end
	-- PortraitFrameTemplate supplies the metal NineSlice, the circular portrait bezel, the title and the close
	-- button, so the journal sits in the client's own window rather than an addon-drawn rectangle.
	local created = CreateFrame("Frame", FRAME_NAME, UIParent, "PortraitFrameTemplate,BackdropTemplate")
	frame = created --[[@as FGWindowFrame]]
	Window.frame = frame
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:Hide()

	BuildHeader(frame)
	BuildBreadcrumb(frame)
	BuildSearch(frame)
	BuildBottom(frame)
	local body = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	body:SetPoint("TOPLEFT", 18, -104)
	body:SetSize(924, PANEL_HEIGHT)

	Window.catalogueNotice = Art.Text(body, "GameFontNormalLarge", "text")
	Window.catalogueNotice:SetPoint("CENTER", frame, "CENTER", 0, -12)
	Window.catalogueNotice:SetWidth(680)
	Window.catalogueNotice:SetJustifyH("CENTER")

	local left = CreateFrame("Frame", nil, frame)
	left:SetPoint("TOPLEFT", 18, -104)
	left:SetSize(LEFT_WIDTH, PANEL_HEIGHT)
	local right = CreateFrame("Frame", nil, frame)
	right:SetPoint("TOPLEFT", 360, -104)
	right:SetSize(582, PANEL_HEIGHT)

	ns.List.Create(left, { Select = Window.SelectSpecies })
	ns.Detail.Create(right)
	Window.creaturePanels = { left, right }
	Window.instances = ns.InstancesView.Create(frame)

	Window.FollowPlayerZone()
	return frame
end

-- The panel manager refuses addon calls in combat. Then the journal opens where the manager puts a left panel, but
-- outside it; the manager drops a frame hidden behind its back from its slots on its own.
local function ShowInCombat(panel)
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	panel:Show()
end

function Window.Show()
	local panel = Create()
	if not panel:IsShown() then
		if InCombatLockdown() then
			ShowInCombat(panel)
		else
			ShowUIPanel(panel)
		end
	end
	Window.Refresh()
end

function Window.Hide()
	if not frame or not frame:IsShown() then
		return
	end
	if InCombatLockdown() then
		frame:Hide()
	else
		HideUIPanel(frame)
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
			Window.Refresh(true)
		end
	end)
end)

ns.On("ZONE_CHANGED_NEW_AREA", function()
	if Window.IsShown() then
		Window.FollowPlayerZone()
	end
end)
