---@type string, BFNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class BFList
local List = {}
ns.List = List

local ROW_HEIGHT = 58
local BAR_WIDTH = 252

---@param row Frame
---@param entry BFListEntry
---@param selectedId integer?
local function UpdateRow(row, entry, selectedId)
	local species = entry.species
	local state = entry.state
	local count = state and state.count or 0
	Art.Icon(row.Icon, Art.FamilyIcon(species.family), 32)
	row.Name:SetText(species.name)
	row.Sub:SetText(string.format(L["%s · Lv %d-%d"], L[species.family], species.minLevel, species.maxLevel))
	row.Counter:SetText(string.format(L["%d / %d"], count, ns.Model.MASTERED_AT))
	row.Fill:SetWidth(BAR_WIDTH * count / ns.Model.MASTERED_AT)
	row.Selected:SetShown(selectedId == species.id)

	local variants = ns.Model.Variants(state, species.id)
	local complete = ns.Model.IsComplete(state, species.id, species)
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
---@return Frame
local function CreateRow(index)
	local row = CreateFrame("Button", nil, List.child)
	row:SetSize(368, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

	row.Background = Art.Texture(row, "BACKGROUND", "panel", 0.55)
	row.Background:SetAllPoints(row)
	row.Selected = Art.Texture(row, "BACKGROUND", "gold", 0.10)
	row.Selected:SetAllPoints(row)
	row.Selected:Hide()

	row.Icon = row:CreateTexture(nil, "ARTWORK")
	row.Icon:SetPoint("TOPLEFT", 10, -10)
	row.Icon:SetSize(32, 32)

	row.Name = Art.Text(row, "GameFontNormal", "text")
	row.Name:SetPoint("TOPLEFT", 52, -7)
	row.Name:SetWidth(250)

	row.Sub = Art.Text(row, "GameFontDisableSmall", "muted")
	row.Sub:SetPoint("TOPLEFT", 52, -26)

	row.Counter = Art.Text(row, "GameFontNormal", "text")
	row.Counter:SetPoint("TOPRIGHT", -14, -7)

	row.Glyph = Art.Text(row, "GameFontNormal", "gold")
	row.Glyph:SetPoint("TOPRIGHT", -14, -29)

	local bar = Art.Bar(row, BAR_WIDTH, 3, "gold")
	bar:SetPoint("TOPLEFT", 52, -48)
	row.Bar, row.Fill = bar, bar.Fill

	row:SetScript("OnClick", function()
		if List.controller and row.species then
			List.controller.Select(row.species.id)
		end
	end)
	row:SetScript("OnEnter", function()
		if row.entry then
			ns.Tooltip.Show(row, row.entry)
		end
	end)
	row:SetScript("OnLeave", function()
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
	child:SetSize(368, 1)
	scroll:SetScrollChild(child)
	List.child = child

	List.empty = Art.Text(parent, "GameFontDisableSmall", "muted")
	List.empty:SetPoint("TOP", parent, "TOP", 0, -36)
	List.empty:SetWidth(330)
	List.empty:SetJustifyH("CENTER")
	List.empty:SetText(L["No creatures match your search."])
	List.empty:Hide()
end

---@param entries BFListEntry[]
---@param selectedId integer?
function List.Refresh(entries, selectedId)
	if not List.child then
		return
	end
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
		List.scroll:SetVerticalScroll(0)
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
