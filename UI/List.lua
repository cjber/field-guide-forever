---@type string, FGNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class FGList
local List = {}
ns.List = List

-- Pet Journal rows: 51 tall art with a 4 gap, the icon in a Collections item border.
local ROW_HEIGHT = 55
local ROW_ART_HEIGHT = 51
local ROW_WIDTH = 300
local MARK_SIZE = 26
local BORDER_SIZE = 45
local NAME_WIDTH = 196
-- Visible rows plus one, the pool the scroll frame recycles. Its size is fixed for the journal's fixed pane.
local OVERSCAN = 1
-- A tagged name gives up room for the tag, so NEW never runs under the variant marks.
local TAGGED_NAME_WIDTH = 150

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
		Art.CreatureIcon(row.Icon, species.name, species.id, BORDER_SIZE - 8)
		row.iconSpecies = species.id
	end
	row.Name:SetText(species.name)
	local character = ns.GetCharacterState(false)
	local record = character and character.species and character.species[species.id]
	local known = record ~= nil and (record.count or 0) > 0
	local bestTier = ns.Model.BestTier(record)
	row.Name:SetTextColor(Art.RGBA(known and "gold" or "muted", 1))
	row.Icon:SetDesaturated(not known)
	local shade = known and 1 or 0.5
	row.Icon:SetVertexColor(shade, shade, shade, 1)
	Art.SetBorderCollected(row.Border, known)
	row.Sub:SetText(
		string.format(L["%s · Level %s"], L[species.family], ns.Model.LevelRange(species.minLevel, species.maxLevel))
	)
	row.Selected:SetShown(selectedId == species.id)
	if bestTier and bestTier ~= "bronze" then
		Art.PaintTierIcon(row.Mark, bestTier, MARK_SIZE)
		row.Mark:SetShown(true)
	else
		row.Mark:Hide()
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

	row.Background = row:CreateTexture(nil, "BACKGROUND")
	row.Background:SetAtlas("petlist-buttonbackground")
	row.Background:SetPoint("TOPLEFT")
	row.Background:SetSize(ROW_WIDTH, ROW_ART_HEIGHT)
	row.Selected = row:CreateTexture(nil, "BORDER")
	row.Selected:SetAtlas("petlist-buttonselect")
	row.Selected:SetAllPoints(row.Background)
	row.Selected:Hide()
	row.Hover = row:CreateTexture(nil, "HIGHLIGHT")
	row.Hover:SetAtlas("petlist-buttonhighlight")
	row.Hover:SetBlendMode("ADD")
	row.Hover:SetAllPoints(row.Background)
	row.Hover:Hide()

	row.Icon, row.Border = Art.BorderedIcon(row, BORDER_SIZE)
	row.Icon:SetPoint("TOPLEFT", 8, -7)

	row.Name = Art.Text(row, "GameFontNormalLarge", "gold")
	row.Name:SetPoint("TOPLEFT", 58, -8)
	row.Name:SetWidth(NAME_WIDTH)
	row.Name:SetJustifyH("LEFT")
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

	row.Sub = Art.Text(row, "GameFontHighlight", "muted")
	row.Sub:SetPoint("TOPLEFT", 58, -30)
	row.Sub:SetWidth(NAME_WIDTH)
	row.Sub:SetJustifyH("LEFT")
	row.Sub:SetWordWrap(false)

	-- The quality mark of the best variant this character has found past bronze. Bronze and undiscovered species
	-- leave the slot empty.
	row.Mark = row:CreateTexture(nil, "OVERLAY")
	row.Mark:SetPoint("RIGHT", row.Background, "RIGHT", -12, 0)
	row.Mark:SetSize(MARK_SIZE, MARK_SIZE)
	row.Mark:Hide()

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
	List.viewHeight = math.max(ROW_HEIGHT, (parent:GetHeight() or 0) - 12)
	List.viewRows = math.ceil(List.viewHeight / ROW_HEIGHT) + OVERSCAN

	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -6)
	scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 6)
	scroll:SetScript("OnVerticalScroll", function()
		List.Update()
	end)
	List.scroll = scroll

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(ROW_WIDTH, 1)
	scroll:SetScrollChild(child)
	List.child = child

	List.empty = Art.Text(parent, "GameFontHighlight", "muted")
	List.empty:SetPoint("TOP", parent, "TOP", 0, -36)
	List.empty:SetWidth(300)
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
