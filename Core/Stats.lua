---@type string, FGNamespace
local _, ns = ...

if ns.broken then
	return
end

---@class FGStatsModule
local Stats = {}
ns.Stats = Stats

-- The metrics this addon counts locally, in one stable order. Stats() reports one all-subject total for each.
local ACTIVITY_METRICS = {
	"boss_first_kill",
	"boss_first_sighting",
	"boss_kills",
	"boss_sightings",
	"bronze_finds",
	"creature_kills",
	"first_bronze",
	"first_gold",
	"first_kill",
	"first_shiny",
	"first_sighting",
	"first_silver",
	"gold_finds",
	"shiny_finds",
	"silver_finds",
}
local FIRST_FIELDS = {
	first_sighting = "firstSighting",
	first_kill = "firstKill",
	first_bronze = "firstBronze",
	first_silver = "firstSilver",
	first_gold = "firstGold",
	first_shiny = "firstShiny",
}

-- Every record this character holds, as (metric, subject, value, eventUnix) observations: the one walk Stats() totals.
-- A zero value or a missing timestamp is passed on as it is; each reader decides what to keep.
---@param state FGState
---@param add fun(metric: string, subject: integer|string, value: number, stamp: number?)
local function EachRecord(state, add)
	for id, entry in pairs(state.species or {}) do
		add("creature_kills", id, ns.Model.ObservedKills(entry), entry.lastKill)
		add("bronze_finds", id, entry.bronze or 0, entry.firstBronze)
		add("silver_finds", id, entry.silver or 0, entry.firstSilver)
		add("gold_finds", id, entry.gold or 0, entry.firstGold)
		add("shiny_finds", id, entry.shiny or 0, entry.firstShiny)
		for metric, field in pairs(FIRST_FIELDS) do
			if entry[field] then
				add(metric, id, 1, entry[field])
			end
		end
	end
	for id, entry in pairs(state.encounters or {}) do
		add("boss_sightings", id, entry.sightings or 0, entry.firstSighting)
		if entry.firstSighting then
			add("boss_first_sighting", id, 1, entry.firstSighting)
		end
		if entry.firstKill then
			add("boss_first_kill", id, 1, entry.firstKill)
		end
		for difficulty, count in pairs(entry.difficulties or {}) do
			add("boss_kills", id .. "_" .. difficulty, count, entry.firstKill)
		end
	end
end

---@param stamp any
---@param now number
---@return number?
local function Stamp(stamp, now)
	return type(stamp) == "number" and stamp > 0 and math.min(stamp, now) or nil
end

-- This character's own totals in the suite's activity-row shape: one row per metric the addon counts, each the sum of
-- that walk's values with subject "all". eventUnix is the latest real timestamp, left out when none exists.
---@return { addon: string, metric: string, subject: string, value: number, eventUnix?: number }[]
function Stats.Activity()
	local state = ns.GetCharacterState(false)
	local values, times = {}, {}
	if state then
		local now = GetServerTime()
		EachRecord(state, function(metric, _, value, stamp)
			if type(value) == "number" and value > 0 then
				values[metric] = (values[metric] or 0) + value
			end
			local at = Stamp(stamp, now)
			if at and (not times[metric] or at > times[metric]) then
				times[metric] = at
			end
		end)
	end
	local rows = {}
	for _, metric in ipairs(ACTIVITY_METRICS) do
		rows[#rows + 1] = {
			addon = "FieldGuideForever",
			metric = metric,
			subject = "all",
			value = values[metric] or 0,
			eventUnix = times[metric],
		}
	end
	return rows
end

return Stats
