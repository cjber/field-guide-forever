---@type string, FGNamespace
local _, ns = ...

-- Field Guide Forever's own lines in /fg report. They answer the questions a bug report usually starts with: how much
-- this character has recorded, whether the catalogue loaded, and whether the two optional pieces are on. English
-- throughout, like the report's field labels, so one report reads the same in every locale.

---@param values? table
---@return integer
local function Count(values)
	local total = 0
	for _ in pairs(values or {}) do
		total = total + 1
	end
	return total
end

---@return string[]
function ns.ReportLines()
	local state = ns.GetCharacterState and ns.GetCharacterState(false) or nil
	local lines = { ("%d creatures recorded for this character"):format(Count(state and state.species)) }

	local status = ns.QuestieDB and ns.QuestieDB.State and ns.QuestieDB.State() or ns.catalogueStatus or "not loaded"
	lines[#lines + 1] = "QuestieDB catalogue: " .. tostring(status)

	local settings = ns.TrackerHostSettings and ns.TrackerHostSettings() or nil
	local tracker = settings and settings.attached == false and "tracker section: detached"
		or "tracker section: attached"
	if state and tonumber(state.tracked) then
		tracker = tracker .. ", tracking a creature"
	else
		tracker = tracker .. ", nothing tracked"
	end
	lines[#lines + 1] = tracker

	local options = ns.db and ns.db.options or {}
	lines[#lines + 1] = "minimap button: " .. (options.minimapButtonHidden and "hidden" or "shown")
	return lines
end
