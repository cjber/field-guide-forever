---@type string, FGNamespace
local _, ns = ...

---@class FGStatsModule
local Stats = {}
ns.Stats = Stats

local SOURCES = {
	fieldguide = {
		creature_kills = "numeric_or_all",
		rare_kills = "numeric",
		shiny_finds = "numeric",
		first_sighting = "numeric",
		first_kill = "numeric",
		first_rare = "numeric",
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
	first_rare = "firstRare",
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

local function Snapshot()
	local state = ns.GetCharacterState(false)
	if not state then
		return {}
	end
	local now, rows, total = GetServerTime(), {}, 0
	local function Add(metric, subject, value, stamp)
		if type(value) ~= "number" or value <= 0 then
			return
		end
		stamp = type(stamp) == "number" and stamp > 0 and math.min(stamp, now) or nil
		rows[#rows + 1] = { metric = metric, subject = tostring(subject), value = value, eventUnix = stamp }
	end
	for id, entry in pairs(state.species) do
		local kills = ns.Model.ObservedKills(entry)
		total = total + kills
		Add("creature_kills", id, kills, entry.lastKill)
		Add("rare_kills", id, entry.rareKills or 0, entry.firstRare)
		Add("shiny_finds", id, entry.shinyFinds or 0, entry.firstShiny)
		for metric, field in pairs(FIRST_FIELDS) do
			if entry[field] then
				Add(metric, id, 1, entry[field])
			end
		end
	end
	for id, entry in pairs(state.encounters) do
		Add("boss_sightings", id, entry.sightings or 0, entry.firstSighting)
		if entry.firstSighting then
			Add("boss_first_sighting", id, 1, entry.firstSighting)
		end
		if entry.firstKill then
			Add("boss_first_kill", id, 1, entry.firstKill)
		end
		for difficulty, count in pairs(entry.difficulties or {}) do
			Add("boss_kills", id .. "_" .. difficulty, count, entry.firstKill)
		end
	end
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

for source, metrics in pairs(SOURCES) do
	local addon = source
	local config = {
		addon = addon,
		enabled = Enabled,
		metrics = {},
		db = function()
			return Store(addon)
		end,
	}
	for metric, mode in pairs(metrics) do
		config.metrics[metric] = { subject = mode, first = metric:find("first_") ~= nil }
	end
	if addon == "fieldguide" then
		config.snapshot = Snapshot
		instances[addon] = ns.PeerStats.New(config)
	else
		instances[addon] = ns.PeerStats.Listen("fieldguide", config)
	end
end

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
