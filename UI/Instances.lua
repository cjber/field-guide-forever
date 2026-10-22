---@type string, FGNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class FGInstancesView
local Instances = {}
ns.InstancesView = Instances

local ROW_HEIGHT = 92

---@param parent Frame
---@return Frame
function Instances.Create(parent)
	local view = CreateFrame("Frame", nil, parent)
	view:SetPoint("TOPLEFT", 18, -146)
	view:SetSize(924, 494)
	view:Hide()
	Instances.view = view

	local title = Art.Text(view, "GameFontNormalLarge", "gold")
	title:SetPoint("TOPLEFT", 4, -4)
	title:SetText(L["Instances"])
	local subtitle = Art.Text(view, "GameFontDisableSmall", "muted")
	subtitle:SetPoint("TOPLEFT", 4, -26)
	subtitle:SetText(L["Boss encounters recorded on this character"])

	local scroll = CreateFrame("ScrollFrame", nil, view, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -48)
	scroll:SetPoint("BOTTOMRIGHT", -26, 0)
	Instances.scroll = scroll
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(890, 1)
	scroll:SetScrollChild(child)
	Instances.child = child
	Instances.rows = {}

	Instances.empty = Art.Text(view, "GameFontDisableSmall", "muted")
	Instances.empty:SetPoint("TOP", view, "TOP", 0, -96)
	Instances.empty:SetWidth(700)
	Instances.empty:SetJustifyH("CENTER")
	Instances.empty:SetText(L["No completed boss encounters recorded yet."])
	return view
end

---@param encounters FGEncounterState[]?
function Instances.Refresh(encounters)
	if not Instances.view then
		return
	end
	encounters = encounters or {}
	for index, encounter in ipairs(encounters) do
		local row = Instances.rows[index]
		if not row then
			row = CreateFrame("Frame", nil, Instances.child, "BackdropTemplate")
			row:SetSize(884, ROW_HEIGHT - 6)
			Art.Card(row, "panel", 0.8)
			row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
			row.name = Art.Text(row, "GameFontNormal", "text")
			row.name:SetPoint("TOPLEFT", 12, -8)
			row.name:SetWidth(540)
			row.count = Art.Text(row, "GameFontHighlightSmall", "gold")
			row.count:SetPoint("TOPRIGHT", -12, -8)
			row.attempts = Art.Text(row, "GameFontDisableSmall", "muted")
			row.attempts:SetPoint("TOPRIGHT", -12, -27)
			row.first = Art.Text(row, "GameFontDisableSmall", "muted")
			row.first:SetPoint("TOPLEFT", 12, -30)
			row.first:SetWidth(860)
			row.sighting = Art.Text(row, "GameFontDisableSmall", "muted")
			row.sighting:SetPoint("TOPLEFT", 12, -48)
			row.sighting:SetWidth(860)
			row.difficulty = Art.Text(row, "GameFontDisableSmall", "muted")
			row.difficulty:SetPoint("TOPLEFT", 12, -66)
			row.difficulty:SetWidth(860)
			Instances.rows[index] = row
		end
		row:Show()
		row.name:SetText(
			string.format(L["%s · %s"], encounter.instance or L["Unknown instance"], encounter.name or "")
		)
		row.count:SetText(string.format(L["%d recorded boss kills"], encounter.kills or 0))
		row.attempts:SetText(string.format(L["%d attempts recorded"], encounter.sightings or 0))
		local stamp = encounter.firstKill and date and date("%Y-%m-%d %H:%M", encounter.firstKill)
			or tostring(encounter.firstKill or "—")
		row.first:SetText(
			string.format(
				L["Personal first boss clear: %s · difficulty %s"],
				stamp,
				encounter.firstDifficultyName or tostring(encounter.firstDifficulty or "—")
			)
		)
		if encounter.firstSighting then
			local sightingStamp = date and date("%Y-%m-%d %H:%M", encounter.firstSighting)
				or tostring(encounter.firstSighting)
			row.sighting:SetText(
				string.format(
					L["Personal first boss sighting: %s · difficulty %s"],
					sightingStamp,
					encounter.firstSightingDifficultyName or tostring(encounter.firstSightingDifficulty or "—")
				)
			)
		else
			row.sighting:SetText("")
		end
		local difficulties = {}
		for difficulty, count in pairs(encounter.difficulties or {}) do
			difficulties[#difficulties + 1] = {
				id = tonumber(difficulty) or 0,
				name = (encounter.difficultyNames or {})[difficulty],
				count = count,
			}
		end
		table.sort(difficulties, function(a, b)
			return a.id < b.id
		end)
		local totals = {}
		for _, record in ipairs(difficulties) do
			totals[#totals + 1] =
				string.format(L["Difficulty %s: %d"], record.name or tostring(record.id), record.count)
		end
		row.difficulty:SetText(table.concat(totals, " · "))
	end
	for index = #encounters + 1, #Instances.rows do
		Instances.rows[index]:Hide()
	end
	Instances.child:SetHeight(math.max(1, #encounters * ROW_HEIGHT))
	Instances.empty:SetShown(#encounters == 0)
	if Instances.scroll and Instances.scroll.SetVerticalScroll then
		Instances.scroll:SetVerticalScroll(0)
	end
end

return Instances
