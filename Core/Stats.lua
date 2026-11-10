---@type string, FGNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L

---@class FGStatsModule
local Stats = {}
ns.Stats = Stats

local SOURCES = {
	fieldguide = {
		creature_kills = "numeric_or_all",
		bronze_finds = "numeric",
		silver_finds = "numeric",
		gold_finds = "numeric",
		shiny_finds = "numeric",
		first_sighting = "numeric",
		first_kill = "numeric",
		first_bronze = "numeric",
		first_silver = "numeric",
		first_gold = "numeric",
		first_shiny = "numeric",
		boss_sightings = "numeric",
		boss_kills = "numeric_pair",
		boss_first_sighting = "numeric",
		boss_first_kill = "numeric",
	},
	spf = {
		distance_yards = "numeric_or_all",
		routes_completed = "numeric_or_all",
		transports_used = "numeric_or_all",
		flights_taken = "numeric_or_all",
		portals_used = "numeric_or_all",
	},
	agf = { quest_turn_ins = "numeric_or_all", quest_turn_in = "numeric_or_all" },
	legacy = { flight_path_known = "numeric_or_all" },
	skillup = { recipes_observed_learned = "numeric_or_all" },
}
local FIRST_FIELDS = {
	first_sighting = "firstSighting",
	first_kill = "firstKill",
	first_bronze = "firstBronze",
	first_silver = "firstSilver",
	first_gold = "firstGold",
	first_shiny = "firstShiny",
}
local instances = {}
local pending = false

local function Enabled()
	return ns.db ~= nil and ns.db.options.statsShare ~= false
end

-- Keep the old public SharedStats shape; persisted records use Core's bounded canonical stores per character.
function Stats.Migrate(db)
	db.peerStats = type(db.peerStats) == "table" and db.peerStats or {}
	local key = ns.CharacterKey()
	local stores = type(db.peerStats[key]) == "table" and db.peerStats[key] or {}
	db.peerStats[key] = stores
	for peer, addons in pairs(type(db.sharedStats) == "table" and db.sharedStats or {}) do
		if type(peer) == "string" and type(addons) == "table" then
			for addon, subjects in pairs(addons) do
				if SOURCES[addon] and type(subjects) == "table" then
					stores[addon] = type(stores[addon]) == "table" and stores[addon] or {}
					local records = type(stores[addon][peer]) == "table" and stores[addon][peer] or {}
					stores[addon][peer] = records
					for subject, metrics in pairs(subjects) do
						if type(subject) == "string" and type(metrics) == "table" then
							for metric, record in pairs(metrics) do
								if SOURCES[addon][metric] and type(record) == "table" then
									records[metric] = type(records[metric]) == "table" and records[metric] or {}
									records[metric][subject] = { value = record.value, eventUnix = record.time }
								end
							end
						end
					end
				end
			end
		end
	end
	db.sharedStats = nil
end

local function Store(addon)
	if not ns.db then
		return nil
	end
	local key = ns.CharacterKey()
	local stores = ns.db.peerStats[key]
	if type(stores) ~= "table" then
		stores = {}
		ns.db.peerStats[key] = stores
	end
	if type(stores[addon]) ~= "table" then
		stores[addon] = {}
	end
	return stores[addon]
end

-- Every record this character holds, as (metric, subject, value, eventUnix) observations: the one walk the peer
-- snapshot and the public Stats() both total, so the two can never disagree about what a metric counts. A zero value
-- or a missing timestamp is passed on as it is; each reader decides what to keep.
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

local function Snapshot()
	local state = ns.GetCharacterState(false)
	if not state then
		return {}
	end
	local now, rows, total = GetServerTime(), {}, 0
	EachRecord(state, function(metric, subject, value, stamp)
		if type(value) ~= "number" or value <= 0 then
			return
		end
		if metric == "creature_kills" then
			total = total + value
		end
		rows[#rows + 1] = { metric = metric, subject = tostring(subject), value = value, eventUnix = Stamp(stamp, now) }
	end)
	-- Bound one source's burst so it cannot fill the suite's shared send queue. Individual reports favor recent
	-- observations; the explicit total includes every species, even when detailed reports are outside this window.
	table.sort(rows, function(a, b)
		if (a.eventUnix or 0) ~= (b.eventUnix or 0) then
			return (a.eventUnix or 0) > (b.eventUnix or 0)
		end
		if a.metric ~= b.metric then
			return a.metric < b.metric
		end
		return a.subject < b.subject
	end)
	for index = #rows, 128, -1 do
		rows[index] = nil
	end
	table.insert(rows, 1, { metric = "creature_kills", subject = "all", value = total })
	return rows
end

-- The metric names this addon reports to the suite, in one stable order.
local ACTIVITY_METRICS = {}
for metric in pairs(SOURCES.fieldguide) do
	ACTIVITY_METRICS[#ACTIVITY_METRICS + 1] = metric
end
table.sort(ACTIVITY_METRICS)

-- This character's own totals in the suite's activity-row shape: one row per metric the peer snapshot reports, each
-- the sum of that walk's values with subject "all". eventUnix is the latest real timestamp, left out when none exists.
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

for source, metrics in pairs(SOURCES) do
	local addon = source
	local config = {
		addon = addon,
		enabled = Enabled,
		metrics = {},
		safeCall = ns.core.SafeCall,
		db = function()
			return Store(addon)
		end,
	}
	for metric, mode in pairs(metrics) do
		config.metrics[metric] = { subject = mode, first = metric:find("first_") ~= nil }
	end
	if addon == "fieldguide" then
		config.snapshot = Snapshot
		instances[addon] = ForeverCore.PeerStats.New(config)
	else
		instances[addon] = ForeverCore.PeerStats.Listen("fieldguide", config)
	end
end

-- This character's observed kill total and its latest kill, the local half of the board.
---@return integer value
---@return number|nil eventUnix
local function LocalKills()
	local state = ns.GetCharacterState(false)
	if not state then
		return 0, nil
	end
	local total, latest = 0, nil
	for _, entry in pairs(state.species) do
		total = total + ns.Model.ObservedKills(entry)
		if type(entry.lastKill) == "number" and entry.lastKill > 0 and (not latest or entry.lastKill > latest) then
			latest = entry.lastKill
		end
	end
	return total, latest
end

-- One row per ranked player, in the shape the shared window draws. The all-time board keeps the cumulative total in
-- the value column; the weekly board draws the progress since the reset there and the cumulative total in grey.
---@param scope ForeverLeaderboardsScope
---@return ForeverLeaderboardsRow[]
local function Board(scope)
	local value, eventUnix = LocalKills()
	local weekly = scope == "week"
	local ranked
	local totals
	if weekly then
		ranked = instances.fieldguide:WeekBoard("creature_kills", "all", value, eventUnix)
		totals = {}
		for _, row in ipairs(instances.fieldguide:Board("creature_kills", "all", value, eventUnix)) do
			totals[row.identity] = row.value
			totals[row.name:lower()] = row.value
		end
	else
		ranked = instances.fieldguide:Board("creature_kills", "all", value, eventUnix)
	end
	local rows = {}
	for _, row in ipairs(ranked) do
		local total = totals and (totals[row.identity] or totals[row.name:lower()])
		rows[#rows + 1] = {
			name = row.name,
			value = row.value,
			extra = total and (total .. " " .. L["total"]) or nil,
			you = row.self == true,
		}
	end
	return rows
end

--- Open the shared Forever Leaderboards window on this addon's tab.
function Stats.Open()
	ForeverCore.Leaderboards:Open("fieldguide")
end

ForeverCore.Leaderboards:Register("fieldguide", {
	title = L["Field Guide Forever"],
	icon = ns.icon,
	metric = L["Creature kills"],
	board = Board,
	revision = function()
		return instances.fieldguide:Revision()
	end,
	sharing = Enabled,
	setSharing = function(shared)
		if ns.db then
			ns.db.options.statsShare = shared == true
		end
		Stats.SetEnabled(shared == true)
		if ns.FireProgress then
			ns.FireProgress()
		end
	end,
	safeCall = ns.core.SafeCall,
})

local function Schedule()
	if pending or not ns.ready then
		return
	end
	pending = true
	C_Timer.After(0, function()
		pending = false
		instances.fieldguide:Sync()
	end)
end

function Stats.SetEnabled(enabled)
	for _, instance in pairs(instances) do
		instance:SetEnabled(enabled == true)
	end
end

function Stats.Shared()
	local result = {}
	for addon, instance in pairs(instances) do
		for peer, metrics in pairs(instance:Shared()) do
			result[peer] = result[peer] or {}
			local subjects = {}
			result[peer][addon] = subjects
			for metric, records in pairs(metrics) do
				for subject, record in pairs(records) do
					subjects[subject] = subjects[subject] or {}
					subjects[subject][metric] = { value = record.value, time = record.eventUnix }
				end
			end
		end
	end
	return result
end

function Stats.Receive(prefix, message, channel, sender)
	local accepted = false
	for _, instance in pairs(instances) do
		accepted = instance:Receive(prefix, message, channel, sender) or accepted
	end
	return accepted
end

ns.OnProgress(Schedule)
ns.On("PLAYER_LOGIN", Schedule)
return Stats
