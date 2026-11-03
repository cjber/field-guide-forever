---@type string, FGNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class FGList
local List = {}
ns.List = List

local ROW_HEIGHT = 46
local ROW_WIDTH = 304
local BAR_WIDTH = 280

---@param row FGListRow
---@param entry FGListEntry
---@param selectedId integer?
local function UpdateRow(row, entry, selectedId)
	local species = entry.species
	local state = entry.state
	local count = state and state.count or 0
	Art.Icon(row.Icon, Art.SpeciesIcon(species.name, species.id), 32)
	row.Name:SetText(species.name)
	local character = ns.GetCharacterState(false)
	local variants = ns.Model.Variants(character, species.id)
	local nameColor = variants.rare.known and "rare" or "text"
	local nr, ng, nb = Art.RGBA(nameColor, 1)
	row.Name:SetTextColor(nr, ng, nb, 1)
	row.Sub:SetText(
		string.format(L["%s · Lv %s"], L[species.family], ns.Model.LevelRange(species.minLevel, species.maxLevel))
	)
	row.Counter:SetText(string.format(L["%d kills"], state and (state.kills or state.count) or 0))
	row.Bar:SetProgress(count / ns.Model.MASTERED_AT)
	row.Selected:SetShown(selectedId == species.id)

	local complete = ns.Model.IsComplete(character, species.id, species)
	if count >= ns.Model.MASTERED_AT then
		row.Glyph:SetText(L["✦"])
		local r, g, b = Art.RGBA("gold", 1)
		row.Glyph:SetTextColor(r, g, b, 1)
	elseif complete then
		row.Glyph:SetText(L["✓"])
		local r, g, b = Art.RGBA("complete", 1)
		row.Glyph:SetTextColor(r, g, b, 1)
	else
		row.Glyph:SetText("")
	end
	if variants.rare.known then
		row.Name:SetTextColor(Art.RGBA("rare", 1))
	else
		row.Name:SetTextColor(Art.RGBA("text", 1))
	end
	row.species = species
	row.entry = entry
end

---@param index integer
---@return FGListRow
local function CreateRow(index)
	local row = CreateFrame("Button", nil, List.child) --[[@as FGListRow]]
	row:SetSize(ROW_WIDTH, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

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
	row.Name:SetWidth(152)
	row.Name:SetWordWrap(false)
	row.Name:SetMaxLines(1)

	row.Sub = Art.Text(row, "GameFontDisableSmall", "muted")
	row.Sub:SetPoint("TOPLEFT", 52, -23)

	row.Counter = Art.Text(row, "GameFontNormal", "text")
	row.Counter:SetPoint("TOPRIGHT", -14, -5)

	row.Glyph = Art.Text(row, "GameFontNormal", "gold")
	row.Glyph:SetPoint("TOPRIGHT", -14, -23)

	local bar = Art.Bar(row, BAR_WIDTH, 3, "gold")
	bar:SetPoint("TOPLEFT", 10, -40)
	row.Bar, row.Fill = bar, bar.Fill

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

	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 0)
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

---@param entries FGListEntry[]
---@param selectedId integer?
---@param preserveScroll boolean?
function List.Refresh(entries, selectedId, preserveScroll)
	if not List.child then
		return
	end
	local offset = preserveScroll and List.scroll:GetVerticalScroll() or 0
	List.entries = entries or {}
	for index, entry in ipairs(List.entries) do
		local row = List.rows[index]
		if not row then
			row = CreateRow(index)
			List.rows[index] = row
		end
		row:Show()
		UpdateRow(row, entry, selectedId)
	end
	for index = #List.entries + 1, #List.rows do
		List.rows[index]:Hide()
	end
	List.child:SetHeight(math.max(1, #List.entries * ROW_HEIGHT))
	List.empty:SetShown(#List.entries == 0)
	if List.scroll and List.scroll.SetVerticalScroll then
		local maximum = math.max(0, List.child:GetHeight() - List.scroll:GetHeight())
		List.scroll:SetVerticalScroll(math.min(offset, maximum))
	end
end

---@param selectedId integer?
function List.SetSelected(selectedId)
	for _, row in ipairs(List.rows or {}) do
		if row.species then
			row.Selected:SetShown(row.species.id == selectedId)
		end
	end
end
