---@type string, FGNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local Art = ns.Art

---@class FGInstancesView
local Instances = {}
ns.InstancesView = Instances

-- The creature tab's geometry: instances on the left in Pet Journal rows, the open instance's card and bosses right.
local LEFT_WIDTH, RIGHT_X, RIGHT_WIDTH, HEIGHT = 330, 342, 582, 514
local ROW_HEIGHT, ROW_ART_HEIGHT, ROW_WIDTH = 55, 51, 300
local BOSS_HEIGHT, BOSS_ART_HEIGHT = 44, 40
local CARD_HEIGHT = 120
local TEXT_X = 120

---@class FGInstanceGroup
---@field name string
---@field id? integer Map ID, when the catalogue knows the instance
---@field instanceType? integer
---@field species FGSpecies[]
---@field rows table[] one per boss: name, kills, sightings, firsts and difficulty totals
---@field done integer bosses killed at least once
---@field visited boolean

---@class FGInstanceRow : Button
---@field Background Texture
---@field Selected Texture
---@field Icon Texture
---@field Border Texture
---@field Name FontString
---@field Sub FontString
---@field Mark Texture
---@field group? FGInstanceGroup

---@class FGBossRow : Frame
---@field Icon Texture
---@field Border Texture
---@field Name FontString
---@field Detail FontString
---@field boss? table

---@type FGInstanceGroup[]
local groups = {}
---@type string?
local selected

---@param timestamp number?
---@return string?
local function Day(timestamp)
	if not timestamp then
		return nil
	end
	return (tostring(date("%d %b", timestamp)):gsub("^0", ""))
end

---@return string
function Instances.Breadcrumb()
	local group
	for _, candidate in ipairs(groups) do
		if candidate.name == selected then
			group = candidate
		end
	end
	if not group then
		return L["Instances"]
	end
	return string.format(L["%s > %s"], group.instanceType == 2 and L["Raids"] or L["Dungeons"], group.name)
end

---@param texture Texture
---@param group FGInstanceGroup
local function PaintInstanceIcon(texture, group)
	texture:SetTexture(group.id and Art.INSTANCE_ICONS[group.id] or Art.BOOK_ICON)
	texture:SetTexCoord(0, 1, 0, 1)
end

---@param owner Frame
---@param boss table
local function ShowBossTooltip(owner, boss)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(boss.name)
	GameTooltip:AddLine(string.format(L["%d recorded boss kills"], boss.kills or 0), 1, 1, 1)
	GameTooltip:AddLine(string.format(L["%d attempts recorded"], boss.sightings or 0), 1, 1, 1)
	local difficulties = {}
	for difficulty, count in pairs(boss.difficulties or {}) do
		difficulties[#difficulties + 1] = {
			id = tonumber(difficulty) or 0,
			name = (boss.difficultyNames or {})[difficulty],
			count = count,
		}
	end
	table.sort(difficulties, function(a, b)
		return a.id < b.id
	end)
	for _, record in ipairs(difficulties) do
		GameTooltip:AddLine(string.format(L["Difficulty %s: %d"], record.name or tostring(record.id), record.count))
	end
	GameTooltip:Show()
end

---@param index integer
---@return FGInstanceRow
local function CreateInstanceRow(index)
	local row = CreateFrame("Button", nil, Instances.child) --[[@as FGInstanceRow]]
	row:SetSize(ROW_WIDTH, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
	row.Background = row:CreateTexture(nil, "BACKGROUND")
	row.Background:SetAtlas("petlist-buttonbackground")
	row.Background:SetPoint("TOPLEFT")
	row.Background:SetSize(ROW_WIDTH, ROW_ART_HEIGHT)
	row.Selected = row:CreateTexture(nil, "BORDER")
	row.Selected:SetAtlas("petlist-buttonselect")
	row.Selected:SetAllPoints(row.Background)
	local hover = row:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAtlas("petlist-buttonhighlight")
	hover:SetBlendMode("ADD")
	hover:SetAllPoints(row.Background)
	row.Icon, row.Border = Art.BorderedIcon(row, 45)
	row.Icon:SetPoint("TOPLEFT", 8, -7)
	row.Name = Art.Text(row, "GameFontNormalLarge", "gold")
	row.Name:SetPoint("TOPLEFT", 58, -8)
	row.Name:SetWidth(196)
	row.Name:SetJustifyH("LEFT")
	row.Name:SetWordWrap(false)
	row.Sub = Art.Text(row, "GameFontHighlight", "muted")
	row.Sub:SetPoint("TOPLEFT", 58, -30)
	row.Sub:SetWidth(196)
	row.Sub:SetJustifyH("LEFT")
	row.Mark = row:CreateTexture(nil, "OVERLAY")
	row.Mark:SetPoint("RIGHT", row.Background, "RIGHT", -12, 0)
	Art.PaintTierIcon(row.Mark, "gold", 26)
	row:SetScript("OnClick", function()
		if row.group then
			selected = row.group.name
			Instances.Draw()
			if ns.Window and ns.Window.breadcrumb then
				ns.Window.breadcrumb.text:SetText(Instances.Breadcrumb())
			end
		end
	end)
	return row
end

---@param index integer
---@return FGBossRow
local function CreateBossRow(index)
	local row = CreateFrame("Frame", nil, Instances.bossChild) --[[@as FGBossRow]]
	row:SetSize(Instances.bossWidth, BOSS_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * BOSS_HEIGHT)
	local background = row:CreateTexture(nil, "BACKGROUND")
	background:SetAtlas("petlist-buttonbackground")
	background:SetPoint("TOPLEFT")
	background:SetSize(Instances.bossWidth, BOSS_ART_HEIGHT)
	row.Icon, row.Border = Art.BorderedIcon(row, 34)
	row.Icon:SetPoint("TOPLEFT", 8, -6)
	row.Name = Art.Text(row, "GameFontNormalLarge", "gold")
	row.Name:SetPoint("LEFT", 48, 2)
	row.Name:SetWidth(260)
	row.Name:SetJustifyH("LEFT")
	row.Name:SetWordWrap(false)
	row.Detail = Art.Text(row, "GameFontHighlight", "text")
	row.Detail:SetPoint("RIGHT", row, "RIGHT", -14, 2)
	row.Detail:SetWidth(220)
	row.Detail:SetJustifyH("RIGHT")
	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		if self.boss then
			ShowBossTooltip(self, self.boss)
		end
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return row
end

---@param parent Frame
---@return Frame
function Instances.Create(parent)
	local view = CreateFrame("Frame", nil, parent)
	view:SetPoint("TOPLEFT", 18, -104)
	view:SetSize(924, HEIGHT)
	view:Hide()
	Instances.view = view

	local left = CreateFrame("Frame", nil, view, "InsetFrameTemplate")
	left:SetPoint("TOPLEFT")
	left:SetSize(LEFT_WIDTH, HEIGHT)
	local scroll = CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -6)
	scroll:SetPoint("BOTTOMRIGHT", -26, 6)
	Instances.scroll = scroll
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(ROW_WIDTH, 1)
	scroll:SetScrollChild(child)
	Instances.child = child
	Instances.rows = {}
	Instances.listEmpty = Art.Text(left, "GameFontHighlight", "muted")
	Instances.listEmpty:SetPoint("TOP", 0, -36)
	Instances.listEmpty:SetWidth(300)
	Instances.listEmpty:SetJustifyH("CENTER")
	Instances.listEmpty:SetText(L["No instances match your search."])

	local right = CreateFrame("Frame", nil, view, "InsetFrameTemplate")
	right:SetPoint("TOPLEFT", RIGHT_X, 0)
	right:SetSize(RIGHT_WIDTH, HEIGHT)
	local card = right:CreateTexture(nil, "BACKGROUND", nil, 1)
	card:SetAtlas("PetJournal-PetCard-BG")
	card:SetPoint("TOPLEFT", 4, -4)
	card:SetSize(RIGHT_WIDTH - 8, CARD_HEIGHT)
	local divider = Art.Divider(right, RIGHT_WIDTH - 8)
	divider:SetPoint("TOPLEFT", 4, -4 - CARD_HEIGHT)
	Instances.icon, Instances.iconBorder = Art.BorderedIcon(right, 90)
	Instances.icon:SetPoint("TOPLEFT", 24, -22)
	Art.SetBorderCollected(Instances.iconBorder, true)
	Instances.name = Art.Text(right, "GameFontHighlightHuge", "gold")
	Instances.name:SetPoint("TOPLEFT", TEXT_X, -20)
	Instances.name:SetWidth(RIGHT_WIDTH - 24 - TEXT_X)
	Instances.name:SetJustifyH("LEFT")
	Instances.sub = Art.Text(right, "GameFontHighlight", "text")
	Instances.sub:SetPoint("TOPLEFT", TEXT_X, -50)
	Instances.sub:SetWidth(RIGHT_WIDTH - 24 - TEXT_X)
	Instances.sub:SetJustifyH("LEFT")
	Instances.progress = Art.Text(right, "GameFontNormalLarge", "gold")
	Instances.progress:SetPoint("TOPLEFT", TEXT_X, -78)
	Instances.progress:SetWidth(RIGHT_WIDTH - 24 - TEXT_X)
	Instances.progress:SetJustifyH("LEFT")

	local band = Art.Header(right, L["Bosses"])
	band:SetPoint("TOPLEFT", 14, -140)
	local bossScroll = CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate")
	bossScroll:SetPoint("TOPLEFT", 16, -180)
	bossScroll:SetPoint("BOTTOMRIGHT", -30, 6)
	Instances.bossScroll = bossScroll
	Instances.bossWidth = RIGHT_WIDTH - 46
	local bossChild = CreateFrame("Frame", nil, bossScroll)
	bossChild:SetSize(Instances.bossWidth, 1)
	bossScroll:SetScrollChild(bossChild)
	Instances.bossChild = bossChild
	Instances.bossRows = {}
	Instances.empty = Art.Text(right, "GameFontHighlight", "muted")
	Instances.empty:SetPoint("TOPLEFT", 26, -188)
	Instances.empty:SetWidth(RIGHT_WIDTH - 52)
	Instances.empty:SetJustifyH("LEFT")
	Instances.empty:SetText(L["No completed boss encounters recorded yet."])

	local bar = CreateFrame("Frame", nil, view, "InsetFrameTemplate")
	bar:SetPoint("TOPLEFT", 0, -HEIGHT - 12)
	bar:SetSize(924, 66)
	local label = Art.Text(bar, "GameFontNormalLarge", "gold")
	label:SetPoint("TOPLEFT", 14, -8)
	label:SetText(L["Dungeons cleared"])
	Instances.cleared = Art.Text(bar, "GameFontNormalLarge", "gold")
	Instances.cleared:SetPoint("TOPLEFT", label, "TOPRIGHT", 10, 0)
	Instances.clearedBar = Art.StatusBar(bar, 320)
	Instances.clearedBar:SetPoint("TOPLEFT", 14, -29)
	Instances.kills = Art.Text(bar, "GameFontHighlightLarge", "text")
	Instances.kills:SetPoint("LEFT", bar, "TOPLEFT", 370, -35)
	return view
end

-- Group the catalogue's bosses and this character's encounter records by instance. A record the catalogue does not
-- list as a boss still gets its own row, under its own instance name.
---@param catalogue FGInstance[]?
---@param personalRecords FGEncounterState[]?
---@return FGInstanceGroup[]
function Instances.Group(catalogue, personalRecords)
	local byName, used, result, byInstance = {}, {}, {}, {}
	for _, record in ipairs(personalRecords or {}) do
		if record.name then
			byName[record.name:lower()] = record
		end
	end
	local function Row(name, record)
		return {
			name = name,
			kills = record and record.kills or 0,
			sightings = record and record.sightings or 0,
			firstKill = record and record.firstKill,
			difficulties = record and record.difficulties or {},
			difficultyNames = record and record.difficultyNames or {},
		}
	end
	for _, map in ipairs(catalogue or {}) do
		local group =
			{ name = map.name, id = map.id, instanceType = map.instanceType, species = map.species, rows = {} }
		for _, species in ipairs(map.species or {}) do
			if species.boss then
				local record = byName[species.name:lower()]
				if record then
					used[record] = true
				end
				group.rows[#group.rows + 1] = Row(species.name, record)
			end
		end
		result[#result + 1] = group
		byInstance[map.name:lower()] = group
	end
	for _, record in ipairs(personalRecords or {}) do
		if not used[record] then
			local instance = record.instance or L["Unknown instance"]
			local group = byInstance[instance:lower()]
			if not group then
				group = { name = instance, species = {}, rows = {} }
				byInstance[instance:lower()] = group
				result[#result + 1] = group
			end
			group.rows[#group.rows + 1] = Row(record.name or "", record)
		end
	end
	for _, group in ipairs(result) do
		local done, visited = 0, false
		for _, row in ipairs(group.rows) do
			if row.kills > 0 then
				done = done + 1
			end
			visited = visited or row.kills > 0 or row.sightings > 0
		end
		group.done, group.visited = done, visited
	end
	table.sort(result, function(a, b)
		if a.visited ~= b.visited then
			return a.visited
		end
		return a.name < b.name
	end)
	return result
end

---@param group FGInstanceGroup
---@param needle string
---@return boolean
local function Matches(group, needle)
	if needle == "" or group.name:lower():find(needle, 1, true) then
		return true
	end
	for _, row in ipairs(group.rows) do
		if row.name:lower():find(needle, 1, true) then
			return true
		end
	end
	return false
end

---@param group FGInstanceGroup
---@return string
local function Subtitle(group)
	local kind = group.instanceType == 2 and L["Raid"] or L["Dungeon"]
	-- Level 1 critters and spell triggers live in most instances; they would pull every range down to 1.
	local low, high
	for _, species in ipairs(group.species) do
		if species.maxLevel > 1 then
			low = math.min(low or species.minLevel, species.minLevel)
			high = math.max(high or species.maxLevel, species.maxLevel)
		end
	end
	if not low then
		return kind
	end
	return string.format(L["%s · Level %s"], kind, ns.Model.LevelRange(low, high))
end

---@param group FGInstanceGroup
---@param name string
---@return FGSpecies?
local function SpeciesNamed(group, name)
	local needle = name:lower()
	for _, species in ipairs(group.species) do
		if species.name:lower() == needle then
			return species
		end
	end
end

local shown = {}

-- Fill the list from the current groups and search, then the open instance's card and bosses.
function Instances.Draw()
	local open
	for index, group in ipairs(shown) do
		local row = Instances.rows[index] or CreateInstanceRow(index)
		Instances.rows[index] = row
		row.group = group
		row:Show()
		local total = #group.rows
		PaintInstanceIcon(row.Icon, group)
		row.Icon:SetDesaturated(not group.visited)
		local shade = group.visited and 1 or 0.5
		row.Icon:SetVertexColor(shade, shade, shade, 1)
		Art.SetBorderCollected(row.Border, group.visited)
		row.Name:SetText(group.name)
		row.Name:SetTextColor(Art.RGBA(group.visited and "gold" or "muted", 1))
		row.Sub:SetText(group.visited and string.format(L["%d of %d bosses"], group.done, total) or L["Not visited"])
		row.Mark:SetShown(total > 0 and group.done == total)
		row.Selected:SetShown(group.name == selected)
		if group.name == selected then
			open = group
		end
	end
	for index = #shown + 1, #Instances.rows do
		Instances.rows[index]:Hide()
		Instances.rows[index].group = nil
	end
	Instances.child:SetHeight(math.max(1, #shown * ROW_HEIGHT))
	Instances.listEmpty:SetShown(#shown == 0)

	local rows = open and open.rows or {}
	Instances.icon:SetShown(open ~= nil)
	Instances.iconBorder:SetShown(open ~= nil)
	if open then
		PaintInstanceIcon(Instances.icon, open)
		Instances.name:SetText(open.name)
		Instances.sub:SetText(Subtitle(open))
		Instances.progress:SetText(string.format(L["%d of %d bosses recorded"], open.done, #rows))
	else
		Instances.name:SetText("")
		Instances.sub:SetText("")
		Instances.progress:SetText("")
	end
	for index, boss in ipairs(rows) do
		local row = Instances.bossRows[index] or CreateBossRow(index)
		Instances.bossRows[index] = row
		row.boss = boss
		row:Show()
		local killed = boss.kills > 0
		local species = SpeciesNamed(open, boss.name)
		if species then
			Art.CreatureIcon(row.Icon, species.name, species.id, 28)
		else
			Art.Icon(row.Icon, Art.GENERIC_CREATURE_ICON, 28)
		end
		row.Icon:SetDesaturated(not killed)
		local shade = killed and 1 or 0.5
		row.Icon:SetVertexColor(shade, shade, shade, 1)
		Art.SetBorderCollected(row.Border, killed)
		row.Name:SetText(boss.name)
		row.Name:SetTextColor(Art.RGBA(killed and "gold" or "muted", 1))
		local detail = L["Not defeated yet"]
		if killed then
			local kills = string.format(boss.kills == 1 and L["%d kill"] or L["%d kills"], boss.kills)
			local first = Day(boss.firstKill)
			detail = first and string.format(L["%s · first %s"], kills, first) or kills
		end
		row.Detail:SetText(detail)
		row.Detail:SetTextColor(Art.RGBA(killed and "text" or "muted", 1))
	end
	for index = #rows + 1, #Instances.bossRows do
		Instances.bossRows[index]:Hide()
		Instances.bossRows[index].boss = nil
	end
	Instances.bossChild:SetHeight(math.max(1, #rows * BOSS_HEIGHT))
	Instances.empty:SetShown(#rows == 0)
end

---@param catalogue FGInstance[]?
---@param personalRecords FGEncounterState[]?
---@param query string?
function Instances.Refresh(catalogue, personalRecords, query)
	if not Instances.view then
		return
	end
	groups = Instances.Group(catalogue, personalRecords)
	local needle = (query or ""):lower()
	shown = {}
	local cleared, total, kills, stillShown = 0, 0, 0, false
	for _, group in ipairs(groups) do
		if group.id then
			total = total + 1
		end
		if #group.rows > 0 and group.done == #group.rows then
			cleared = cleared + 1
		end
		for _, row in ipairs(group.rows) do
			kills = kills + row.kills
		end
		if Matches(group, needle) then
			shown[#shown + 1] = group
			stillShown = stillShown or group.name == selected
		end
	end
	if not stillShown then
		selected = shown[1] and shown[1].name or nil
	end
	Instances.cleared:SetText(string.format(L["%d of %d"], cleared, total))
	Instances.clearedBar:SetFillPercent(total > 0 and cleared / total or 0)
	Instances.kills:SetText(string.format(L["%d boss kills recorded"], kills))
	Instances.Draw()
	Instances.bossScroll:SetVerticalScroll(0)
end

return Instances
