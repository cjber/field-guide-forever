---@type string, FGNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class FGList
local List = {}
ns.List = List

local ROW_HEIGHT = 46
local ROW_WIDTH = 304
local MARK_SIZE = 16
local MARK_GAP = 6
local NAME_WIDTH = 152
-- Visible rows plus one, the pool the scroll frame recycles. Its size is fixed for the journal's fixed pane.
local OVERSCAN = 1
-- A tagged name gives up room for the tag, so NEW never runs under the variant marks.
local TAGGED_NAME_WIDTH = 110

-- The mount journal's New tag (Blizzard_MountCollection.xml): NEW after the name's text, over collections-newglow.
---@param row FGListRow
---@param shown boolean
local function SetNew(row, shown)
	row.Name:SetWidth(shown and TAGGED_NAME_WIDTH or NAME_WIDTH)
	row.New:SetShown(shown)
	row.NewGlow:SetShown(shown)
	if shown then
		row.New:ClearAllPoints()
		row.New:SetPoint("LEFT", row.Name, "LEFT", math.min(row.Name:GetStringWidth(), TAGGED_NAME_WIDTH) + 8, 0)
	end
end

---@param row FGListRow
---@param entry FGListEntry
---@param selectedId integer?
local function UpdateRow(row, entry, selectedId)
	local species = entry.species
	if row.iconSpecies ~= species.id then
		Art.CreatureIcon(row.Icon, species.name, species.id, 32)
		row.iconSpecies = species.id
	end
	row.Name:SetText(species.name)
	local character = ns.GetCharacterState(false)
	local variants = ns.Model.Variants(character, species.id)
	local nameColor = variants.rare.known and "rare" or "text"
	local nr, ng, nb = Art.RGBA(nameColor, 1)
	row.Name:SetTextColor(nr, ng, nb, 1)
	row.Sub:SetText(
		string.format(L["%s · Lv %s"], L[species.family], ns.Model.LevelRange(species.minLevel, species.maxLevel))
	)
	row.Selected:SetShown(selectedId == species.id)
	local icon = Art.SpeciesIcon(species.name, species.id)
	Art.VariantMark(row.Marks.common, "common", variants.common.known, icon)
	Art.VariantMark(row.Marks.rare, "rare", variants.rare.known, icon, not ns.Model.HasRareForm(character, species))
	Art.VariantMark(row.Marks.shiny, "shiny", variants.shiny.known, icon)
	if variants.rare.known then
		row.Name:SetTextColor(Art.RGBA("rare", 1))
	else
		row.Name:SetTextColor(Art.RGBA("text", 1))
	end
	SetNew(row, character ~= nil and character.unseen ~= nil and character.unseen[species.id] == true)
	row.species = species
	row.entry = entry
end

---@param index integer
---@return FGListRow
local function CreateRow(index)
	local row = CreateFrame("Button", nil, List.child) --[[@as FGListRow]]
	row:SetSize(ROW_WIDTH, ROW_HEIGHT)
	row.index = index

	-- The same additive row highlight used by the native quest and collection lists.
	row.Selected = row:CreateTexture(nil, "BACKGROUND")
	row.Selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	row.Selected:SetBlendMode("ADD")
	row.Selected:SetAllPoints(row)
	row.Selected:Hide()
	row.Hover = row:CreateTexture(nil, "HIGHLIGHT")
	row.Hover:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	row.Hover:SetBlendMode("ADD")
	row.Hover:SetAllPoints(row)
	row.Hover:Hide()

	row.Icon = row:CreateTexture(nil, "ARTWORK")
	row.Icon:SetPoint("TOPLEFT", 10, -5)
	row.Icon:SetSize(32, 32)

	row.Name = Art.Text(row, "GameFontNormal", "text")
	row.Name:SetPoint("TOPLEFT", 52, -5)
	row.Name:SetWidth(NAME_WIDTH)
	row.Name:SetWordWrap(false)
	row.Name:SetMaxLines(1)

	row.New = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.New:SetText(L["NEW"])
	if NEW_FEATURE_SHADOW_COLOR then
		row.New:SetShadowColor(NEW_FEATURE_SHADOW_COLOR:GetRGBA())
	end
	row.New:Hide()
	row.NewGlow = row:CreateTexture(nil, "OVERLAY")
	row.NewGlow:SetAtlas("collections-newglow")
	row.NewGlow:SetPoint("TOPLEFT", row.New, "TOPLEFT", -20, 10)
	row.NewGlow:SetPoint("BOTTOMRIGHT", row.New, "BOTTOMRIGHT", 20, -10)
	row.NewGlow:Hide()

	row.Sub = Art.Text(row, "GameFontDisableSmall", "muted")
	row.Sub:SetPoint("TOPLEFT", 52, -23)

	-- Common, rare and shiny, left to right: lit when collected, dark while missing, empty with no rare form.
	row.Marks = {}
	for slot, kind in ipairs({ "common", "rare", "shiny" }) do
		local mark = Art.CreateVariantMark(row, MARK_SIZE)
		mark:SetPoint("RIGHT", row, "RIGHT", -14 - (3 - slot) * (MARK_SIZE + MARK_GAP), 0)
		row.Marks[kind] = mark
	end

	row:SetScript("OnClick", function()
		if List.controller and row.species then
			List.controller.Select(row.species.id)
		end
	end)
	row:SetScript("OnEnter", function()
		row.Hover:Show()
		if row.entry then
			ns.Tooltip.Show(row, row.entry)
		end
	end)
	row:SetScript("OnLeave", function()
		row.Hover:Hide()
		ns.Tooltip.Hide()
	end)
	return row
end

---@param parent Frame
---@param controller { Select: fun(speciesId: integer) }
function List.Create(parent, controller)
	List.controller = controller
	List.rows = {}
	List.entries = {}
	List.viewHeight = math.max(ROW_HEIGHT, parent:GetHeight() or 0)
	List.viewRows = math.ceil(List.viewHeight / ROW_HEIGHT) + OVERSCAN

	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 0)
	scroll:SetScript("OnVerticalScroll", function()
		List.Update()
	end)
	List.scroll = scroll

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(ROW_WIDTH, 1)
	scroll:SetScrollChild(child)
	List.child = child

	List.empty = Art.Text(parent, "GameFontDisableSmall", "muted")
	List.empty:SetPoint("TOP", parent, "TOP", 0, -36)
	List.empty:SetWidth(304)
	List.empty:SetJustifyH("CENTER")
	List.empty:SetText(L["No creatures match your search."])
	List.empty:Hide()
end

-- Fill only the rows on screen, from the scroll frame's offset. Scrolling recycles this fixed pool; it never creates
-- a row per creature, and nothing here runs from OnUpdate.
function List.Update()
	if not List.child then
		return
	end
	local total = #List.entries
	local offset = List.scroll and List.scroll:GetVerticalScroll() or 0
	local first = math.floor(offset / ROW_HEIGHT) + 1
	local last = math.min(total, first + List.viewRows - 1)
	local poolIndex = 1
	for index = first, last do
		local row = List.rows[poolIndex]
		if not row then
			row = CreateRow(index)
			List.rows[poolIndex] = row
		end
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
		row.index = index
		row:Show()
		UpdateRow(row, List.entries[index], List.selectedId)
		poolIndex = poolIndex + 1
	end
	for index = poolIndex, #List.rows do
		local row = List.rows[index]
		row:Hide()
		row.index = nil
		row.species = nil
		row.entry = nil
	end
end

---@param entries FGListEntry[]
---@param selectedId integer?
---@param preserveScroll boolean?
function List.Refresh(entries, selectedId, preserveScroll)
	if not List.child then
		return
	end
	local offset = preserveScroll and List.scroll:GetVerticalScroll() or 0
	List.entries = entries or {}
	List.selectedId = selectedId
	List.child:SetHeight(math.max(1, #List.entries * ROW_HEIGHT))
	List.empty:SetShown(#List.entries == 0)
	if List.scroll and List.scroll.SetVerticalScroll then
		local maximum = math.max(0, List.child:GetHeight() - List.viewHeight)
		List.scroll:SetVerticalScroll(math.min(offset, maximum))
	end
	List.Update()
end

---@param selectedId integer?
function List.SetSelected(selectedId)
	List.selectedId = selectedId
	for _, row in ipairs(List.rows or {}) do
		if row.species then
			row.Selected:SetShown(row.species.id == selectedId)
		end
	end
end

-- A species the journal has now shown loses its tag at once, without waiting for the next refresh.
---@param speciesId integer
function List.ClearNew(speciesId)
	for _, row in ipairs(List.rows or {}) do
		if row.species and row.species.id == speciesId then
			SetNew(row, false)
		end
	end
end
