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

-- An addon-owned window drawn with the Adventure Guide's portrait frame. It opens itself rather than through the
-- panel manager: any addon ShowUIPanel or HideUIPanel taints the gamepad frame bookkeeping, even with the gamepad
-- interface off, and the client's next secure gamepad call is then blocked and blamed on this addon (#253).
-- UISpecialFrames lets Escape close it.
if type(UISpecialFrames) == "table" then
	table.insert(UISpecialFrames, FRAME_NAME)
end

---@type FGWindowFrame?
local frame
---@type integer?
local selectedId
local tab = "creatures"
local filter = "discovered"
local query = ""
local zoneIndex = 1

local tabs = {
	{
		key = "creatures",
		text = "Creatures",
		detail = "Every creature of a zone, its sightings and variants",
		icon = "Interface\\Icons\\INV_Misc_Book_09",
	},
	{
		key = "instances",
		text = "Instances",
		detail = "Boss encounters recorded on this character",
		icon = "Interface\\Icons\\INV_Chest_Chain_05",
	},
}

local filters = {
	{ key = "all", text = "All" },
	{ key = "discovered", text = "Discovered" },
	{ key = "undiscovered", text = "Undiscovered" },
	{ key = "mastered", text = "Mastered" },
	{ key = "silver", text = "Silver found" },
	{ key = "gold", text = "Gold found" },
	{ key = "shiny", text = "Shiny found" },
	{ key = "missingShiny", text = "Missing shiny" },
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
		-- The template's own tooltip, with a second line saying what the tab holds.
		button.GetTooltipTextSetupFunction = function()
			return function(tooltip)
				tooltip:SetText(L[info.text])
				tooltip:AddLine(L[info.detail], 1, 1, 1, true)
				return true
			end
		end
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

	local placeholder = Art.Text(search, "GameFontDisable", "muted")
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

	local filterButton = MakeButton(parent, L["Discovered"], 128, false)
	filterButton:SetPoint("TOPLEFT", 288, -62)
	filterButton:SetHeight(24)
	Window.filterButton = filterButton
	filterButton:SetScript("OnClick", function()
		Window.ToggleFilterMenu()
	end)

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
	breadcrumb.text = Art.Text(breadcrumb, "GameFontHighlightMedium", "text")
	breadcrumb.text:SetPoint("LEFT")
	breadcrumb.arrow = breadcrumb:CreateTexture(nil, "ARTWORK")
	breadcrumb.arrow:SetAtlas("common-dropdown-c-button-hover-arrow")
	breadcrumb.arrow:SetSize(12, 5)
	breadcrumb.arrow:SetPoint("LEFT", breadcrumb.text, "RIGHT", 4, 0)
	Window.breadcrumb = breadcrumb
end

---@param parent Frame
local function BuildBottom(parent)
	-- The footer is two rows: the zone's name and count, then the client's 29-high progress bar with the variant
	-- totals and the two buttons level with it.
	local bar = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	bar:SetPoint("BOTTOMLEFT", 18, 12)
	bar:SetSize(924, 66)
	Window.bottomBar = bar

	local label = Art.Text(bar, "GameFontNormalLarge", "gold")
	label:SetPoint("TOPLEFT", 14, -8)
	label:SetText(L["Zone completion"])

	Window.progressText = Art.Text(bar, "GameFontNormalLarge", "gold")
	Window.progressText:SetPoint("TOPLEFT", label, "TOPRIGHT", 10, 0)

	Window.progressCount = Art.Text(bar, "GameFontHighlight", "muted")
	Window.progressCount:SetPoint("TOPRIGHT", bar, "TOPLEFT", 334, -10)
	Window.progressCount:SetWidth(120)
	Window.progressCount:SetJustifyH("RIGHT")

	Window.progressBar = Art.StatusBar(bar, 320)
	Window.progressBar:SetPoint("TOPLEFT", 14, -29)

	-- How many of this zone's species have each standout variant: its quality mark, then the count.
	Window.totals = {}
	local previous
	for _, tier in ipairs({ "silver", "gold", "shiny" }) do
		local icon = bar:CreateTexture(nil, "ARTWORK")
		Art.PaintTierIcon(icon, tier, 26)
		if previous then
			icon:SetPoint("LEFT", previous, "RIGHT", 20, 0)
		else
			icon:SetPoint("LEFT", bar, "TOPLEFT", 370, -30)
		end
		local value = Art.Text(bar, "GameFontHighlightLarge", "text")
		value:SetPoint("LEFT", icon, "RIGHT", 4, 0)
		Window.totals[tier] = { icon = icon, value = value }
		previous = value
	end

	Window.openButton = MakeButton(bar, L["Open Journal"], 120, false)
	Window.openButton:SetPoint("TOPRIGHT", -140, -30)
	Window.openButton:SetScript("OnClick", function()
		Window.Show()
		Window.SetTab("creatures")
	end)

	Window.trackButton = MakeButton(bar, L["Track Species"], 120, true)
	Window.trackButton:SetPoint("TOPRIGHT", -12, -30)
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
	if options.showUndiscovered == false and count == 0 then
		return false
	end
	if filter == "discovered" and count == 0 then
		return false
	elseif filter == "undiscovered" and count > 0 then
		return false
	elseif filter == "mastered" and count < ns.Model.MASTERED_AT then
		return false
	elseif filter == "silver" and (not entry or entry.silver <= 0) then
		return false
	elseif filter == "gold" and (not entry or entry.gold <= 0) then
		return false
	elseif filter == "shiny" and (not entry or entry.shiny <= 0) then
		return false
	elseif filter == "missingShiny" and entry and entry.shiny > 0 then
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
	for _, species in ipairs(CurrentZone().species) do
		Add(species)
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
	Window.progressCount:SetText(string.format(L["%d of %d"], progress.catalogued, progress.total))
	Window.progressBar:SetFillPercent(progress.fraction)
	local totals = ns.Model.TierTotals(state, zone.species)
	for tier, widgets in pairs(Window.totals) do
		widgets.value:SetText(tostring(totals[tier]))
	end
end

local function UpdateTrackButton()
	local tracked = selectedId and ns.Tracker.IsTracked(selectedId)
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
		Window.body:Show()
		Window.catalogueNotice:Show()
		Window.catalogueNotice:SetText(
			ns.catalogueStatus == "loading" and L["Loading QuestieDB catalogue…"]
				or L["Install QuestieDB or Questie to load the creature catalogue.\nhttps://www.curseforge.com/wow/addons/questie"]
		)
		return
	end
	Window.catalogueNotice:Hide()
	Window.body:Hide()
	for _, button in ipairs(Window.tabButtons or {}) do
		button:Show()
	end
	if tab == "instances" then
		for _, panel in ipairs(Window.creaturePanels or {}) do
			panel:Hide()
		end
		Window.instances:Show()
		Window.bottomBar:Hide()
		Window.filterButton:Hide()
		Window.search:Show()
		Window.searchPlaceholder:SetText(L["Search instances"])
		Window.searchPlaceholder:SetShown(query == "")
		ns.InstancesView.Refresh(ns.Instances, ns.API.Encounters(), query)
		-- The instances breadcrumb names the open instance; there is no zone menu behind it.
		Window.breadcrumb:Show()
		Window.breadcrumb:Disable()
		Window.breadcrumb.arrow:Hide()
		Window.breadcrumb.text:SetText(ns.InstancesView.Breadcrumb())
		UpdateTabs()
		return
	end
	for _, panel in ipairs(Window.creaturePanels or {}) do
		panel:Show()
	end
	Window.instances:Hide()
	Window.bottomBar:Show()
	Window.breadcrumb:Show()
	Window.breadcrumb:Enable()
	Window.breadcrumb.arrow:Show()
	Window.search:Show()
	Window.searchPlaceholder:SetText(L["Search creatures"])
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
	local emptyText = L["No creatures match your search."]
	if #entries == 0 and filter == "discovered" and query == "" then
		emptyText =
			L["Nothing discovered here yet. Defeat a creature or hover its nameplate to add it to your journal."]
	end
	ns.List.SetEmptyText(emptyText)
	ns.List.Refresh(entries, selectedId, preserveScroll)
	Window.UpdateDetail()
	UpdateProgress()
	UpdateBreadcrumb()
	UpdateTabs()
	UpdateFilterButton()
end

---@param key string
function Window.SetTab(key)
	if key ~= tab and query ~= "" then
		-- Each tab searches its own list, so a search does not follow the reader to the other tab.
		query = ""
		Window.search:SetText("")
	end
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
	if not selectedId then
		return
	end
	ns.Tracker.Toggle(selectedId)
	Window.Refresh(true)
end

function Window.ToggleZoneMenu()
	if not frame or not Window.breadcrumb then
		return
	end
	ns.ContextMenu(Window.breadcrumb, function(_, root)
		-- Every zone is a row: past 20 rows of 20 px the menu scrolls rather than running off the screen (WFA-36).
		root:SetScrollMode(20 * 20)
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
	ns.ContextMenu(Window.filterButton, function(_, root)
		root:CreateTitle(L["Filter species"])
		for _, info in ipairs(filters) do -- menu-scroll-ok: filters is eight fixed species filters
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
	-- One inset across the body, shown only while the catalogue is missing; the panes bring their own insets.
	local body = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	body:SetPoint("TOPLEFT", 18, -104)
	body:SetSize(924, PANEL_HEIGHT)
	body:Hide()
	Window.body = body

	Window.catalogueNotice = Art.Text(frame, "GameFontNormalLarge", "text")
	Window.catalogueNotice:SetPoint("CENTER", frame, "CENTER", 0, -12)
	Window.catalogueNotice:SetWidth(680)
	Window.catalogueNotice:SetJustifyH("CENTER")

	local left = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
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

-- The panel manager refuses addon calls in combat, and any addon call to its ShowUIPanel or HideUIPanel writes the
-- gamepad frame bookkeeping (and the event registry it runs through) under the addon's taint. The client's next
-- secure SetPreferredGamepadInteractTarget call is then refused and blamed on Field Guide Forever, even when the
-- gamepad interface was off at the time and is turned on later (#253). The journal is an addon-owned frame, so it
-- opens where the manager puts a left panel and closes itself, as it already does in combat; UISpecialFrames keeps
-- Escape closing it.
local function ShowOutsideManager(panel)
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	panel:Show()
end

function Window.Show()
	local panel = Create()
	if not panel:IsShown() then
		ShowOutsideManager(panel)
	end
	Window.Refresh()
end

function Window.Hide()
	if not frame or not frame:IsShown() then
		return
	end
	frame:Hide()
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
