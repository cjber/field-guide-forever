---@type string, FGNamespace
local _, ns = ...

local Stats = {}
ns.Stats = Stats

local PREFIX = "WFAStats"
local ADDON_ID = "fieldguide"
local ADDON_IDS = { spf = true, fieldguide = true, agf = true, legacy = true, skillup = true }
local PEER_LIMIT = 100
local ROW_LIMIT = 256
local METRIC_LIMIT = 12
local ACCEPTED = { GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }
local FIRST_METRICS = {
	first_sighting = true,
	first_kill = true,
	first_rare = true,
	first_shiny = true,
	boss_first_sighting = true,
	boss_first_kill = true,
}
local METRICS = {
	creature_kills = true,
	rare_kills = true,
	shiny_finds = true,
	first_sighting = true,
	first_kill = true,
	first_rare = true,
	first_shiny = true,
	boss_sightings = true,
	boss_kills = true,
	boss_first_sighting = true,
	boss_first_kill = true,
}
local ALLOWED_METRICS = {
	fieldguide = METRICS,
	spf = {
		distance_yards = true,
		routes_completed = true,
		transports_used = true,
		flights_taken = true,
		portals_used = true,
	},
	agf = { quest_turn_ins = true, quest_turn_in = true },
	legacy = { flight_path_known = true },
	skillup = { recipes_observed_learned = true },
}
local pending = {}
local sent = {}
local queueActive = false
local SEND_SPACING = 1.5

local function Enabled()
	return ns.db and ns.db.options.statsShare ~= false
end

local function DistributionChannels()
	local channels = {}
	if IsInGuild and IsInGuild() then
		channels[#channels + 1] = "GUILD"
	end
	if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		channels[#channels + 1] = "INSTANCE_CHAT"
	elseif IsInRaid and IsInRaid() then
		channels[#channels + 1] = "RAID"
	elseif IsInGroup and IsInGroup() then
		channels[#channels + 1] = "PARTY"
	end
	return channels
end

local function Schedule()
	if queueActive or not C_Timer or not C_Timer.After then
		return
	end
	queueActive = true
	C_Timer.After(SEND_SPACING, function()
		queueActive = false
		local key, item = next(pending)
		if not item then
			return
		end
		local allowed = false
		for _, channel in ipairs(DistributionChannels()) do
			allowed = allowed or channel == item.channel
		end
		if not allowed and Enabled() then
			pending[key] = item
			return
		end
		pending[key] = nil
		local delivered = false
		local throttled = false
		if Enabled() and C_ChatInfo and C_ChatInfo.SendAddonMessage then
			local payload =
				string.format("1|%s|%s|%s|%d|%d", ADDON_ID, item.metric, item.subject, item.value, item.time)
			local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, item.channel)
			local resultCodes = Enum and Enum.SendAddonMessageResult
			if ok and (result == nil or result == true or (resultCodes and result == resultCodes.Success)) then
				delivered = true
			elseif
				resultCodes and (result == resultCodes.AddonMessageThrottle or result == resultCodes.ChannelThrottle)
			then
				throttled = true
			end
		end
		if delivered then
			sent[item.key] = { value = item.value, time = item.time }
		elseif throttled and Enabled() then
			pending[item.key] = item
			C_Timer.After(SEND_SPACING * 2, Schedule)
			return
		end
		if next(pending) then
			Schedule()
		end
	end)
end

local function Queue(metric, subject, value, timestamp)
	if not Enabled() or not METRICS[metric] then
		return
	end
	local id = metric .. "|" .. subject
	for _, channel in ipairs(DistributionChannels()) do
		local key = id .. "|" .. channel
		local previous = sent[key]
		if
			not previous
			or not (
				FIRST_METRICS[metric] and previous.time <= timestamp
				or not FIRST_METRICS[metric] and previous.value >= value
			)
		then
			pending[key] = {
				key = key,
				metric = metric,
				subject = subject,
				value = FIRST_METRICS[metric] and 1 or value,
				time = timestamp,
				channel = channel,
			}
		end
	end
	Schedule()
end

local function SyncLocal()
	if not ns.ready then
		return
	end
	local state = ns.GetCharacterState(false)
	if not state then
		return
	end
	local timestamp = time and time() or 0
	for speciesId, entry in pairs(state.species or {}) do
		if entry.killsEstimated and entry.sharedKillsBaseline == nil then
			entry.sharedKillsBaseline = entry.kills or entry.count or 0
		end
		local kills = math.max(0, (entry.kills or 0) - (entry.sharedKillsBaseline or 0))
		if kills > 0 then
			Queue("creature_kills", tostring(speciesId), kills, entry.lastKill or timestamp)
		end
		if (entry.rareKills or 0) > 0 then
			Queue("rare_kills", tostring(speciesId), entry.rareKills, entry.firstRare or timestamp)
		end
		if (entry.shinyFinds or 0) > 0 then
			Queue("shiny_finds", tostring(speciesId), entry.shinyFinds, entry.firstShiny or timestamp)
		end
		for metric, field in pairs({
			first_sighting = "firstSighting",
			first_kill = "firstKill",
			first_rare = "firstRare",
			first_shiny = "firstShiny",
		}) do
			if entry[field] then
				Queue(metric, tostring(speciesId), 1, entry[field])
			end
		end
	end
	for encounterId, encounter in pairs(state.encounters or {}) do
		local subject = tostring(encounterId)
		if (encounter.sightings or 0) > 0 then
			Queue("boss_sightings", subject, encounter.sightings, encounter.firstSighting or timestamp)
		end
		if encounter.firstSighting then
			Queue("boss_first_sighting", subject, 1, encounter.firstSighting)
		end
		if encounter.firstKill then
			Queue("boss_first_kill", subject, 1, encounter.firstKill)
		end
		for difficulty, count in pairs(encounter.difficulties or {}) do
			Queue("boss_kills", subject .. "_" .. tostring(difficulty), count, encounter.firstKill or timestamp)
		end
	end
end

local function ValidSubject(subject)
	if #subject > 24 then
		return false
	end
	local first, second = subject:match("^(%d+)_(%d+)$")
	local value = tonumber(subject) or tonumber(first)
	local qualifier = second and tonumber(second)
	return value ~= nil
		and value > 0
		and value <= 1000000000
		and (not second or (qualifier and qualifier <= 1000000000))
end

local function IsFirstMetric(metric)
	return FIRST_METRICS[metric] or metric:match("^first_") ~= nil or metric:match("_first_") ~= nil
end

local function ValidMetric(addon, metric)
	return ALLOWED_METRICS[addon] and ALLOWED_METRICS[addon][metric] == true
end

local function PeerCount(peers)
	local count = 0
	for _ in pairs(peers) do
		count = count + 1
	end
	return count
end

local function RowCount(peer)
	local count = 0
	for addon, subjects in pairs(peer) do
		if ADDON_IDS[addon] and type(subjects) == "table" then
			for _ in pairs(subjects) do
				count = count + 1
			end
		end
	end
	return count
end

local function SanitizeShared()
	if not ns.db then
		return
	end
	local shared = type(ns.db.sharedStats) == "table" and ns.db.sharedStats or {}
	ns.db.sharedStats = shared
	local peers = {}
	for name, peer in pairs(shared) do
		if type(name) == "string" and #name <= 64 and type(peer) == "table" then
			peers[#peers + 1] = name
		else
			shared[name] = nil
		end
	end
	table.sort(peers)
	for index, name in ipairs(peers) do
		local peer = shared[name]
		if index > PEER_LIMIT then
			shared[name] = nil
		else
			local rows = 0
			local addons = {}
			for addon in pairs(peer) do
				if ADDON_IDS[addon] and type(peer[addon]) == "table" then
					addons[#addons + 1] = addon
				end
			end
			table.sort(addons)
			for addon, subjects in pairs(peer) do
				if not ADDON_IDS[addon] or type(subjects) ~= "table" then
					peer[addon] = nil
				end
			end
			for _, addon in ipairs(addons) do
				local subjects = peer[addon]
				local subjectNames = {}
				for subject in pairs(subjects) do
					if type(subject) == "string" and ValidSubject(subject) then
						subjectNames[#subjectNames + 1] = subject
					else
						subjects[subject] = nil
					end
				end
				table.sort(subjectNames)
				for subjectIndex, subject in ipairs(subjectNames) do
					local metrics = subjects[subject]
					if subjectIndex + rows > ROW_LIMIT or type(metrics) ~= "table" then
						subjects[subject] = nil
					else
						local names = {}
						for metric in pairs(metrics) do
							if type(metric) == "string" and ValidMetric(addon, metric) then
								names[#names + 1] = metric
							else
								metrics[metric] = nil
							end
						end
						table.sort(names)
						for metricIndex = METRIC_LIMIT + 1, #names do
							metrics[names[metricIndex]] = nil
						end
						for _, metric in ipairs(names) do
							local data = metrics[metric]
							if
								type(data) ~= "table"
								or type(data.value) ~= "number"
								or data.value < 1
								or data.value > 1000000000
								or type(data.time) ~= "number"
								or data.time < 1
								or data.time > (time and time() or 0) + 300
							then
								metrics[metric] = nil
							end
						end
						if next(metrics) then
							rows = rows + 1
						else
							subjects[subject] = nil
						end
					end
				end
			end
			if not next(peer) then
				shared[name] = nil
			end
		end
	end
end

local function IsSelf(sender)
	local name = UnitName and UnitName("player")
	local realm = GetRealmName and GetRealmName()
	return sender == name or sender == (name and realm and (name .. "-" .. realm))
end

local function Receive(prefix, message, channel, sender)
	if not Enabled() or prefix ~= PREFIX or not ACCEPTED[channel] or type(sender) ~= "string" or #sender > 64 then
		return
	end
	if type(message) ~= "string" or #message > 128 or IsSelf(sender) then
		return
	end
	local version, addon, metric, subject, value, eventTime =
		message:match("^(%d)|([%a%d_]+)|([%a%d_]+)|([%d_]+)|(%d+)|(%d+)$")
	if version ~= "1" or not ADDON_IDS[addon] or not ValidMetric(addon, metric) or not ValidSubject(subject) then
		return
	end
	value, eventTime = tonumber(value), tonumber(eventTime)
	if
		not value
		or not eventTime
		or value < 1
		or value > 1000000000
		or eventTime < 1
		or eventTime > (time and time() or 0) + 300
	then
		return
	end
	local db = ns.db
	SanitizeShared()
	db.sharedStats = db.sharedStats or {}
	local peer = db.sharedStats[sender]
	if not peer then
		if PeerCount(db.sharedStats) >= PEER_LIMIT then
			return
		end
		peer = {}
		db.sharedStats[sender] = peer
	end
	local addonStats = peer[addon]
	if not addonStats then
		addonStats = {}
		peer[addon] = addonStats
	end
	local subjectStats = addonStats[subject]
	if not subjectStats then
		if RowCount(peer) >= ROW_LIMIT then
			return
		end
		subjectStats = {}
		addonStats[subject] = subjectStats
	end
	local current = subjectStats[metric]
	if not current then
		local metrics = 0
		for _ in pairs(subjectStats) do
			metrics = metrics + 1
		end
		if metrics >= METRIC_LIMIT then
			return
		end
	end
	if IsFirstMetric(metric) then
		if not current or eventTime < current.time then
			subjectStats[metric] = { value = 1, time = eventTime }
		end
	elseif not current or value > current.value then
		subjectStats[metric] = { value = value, time = eventTime }
	end
end

function Stats.SetEnabled(enabled)
	if not enabled then
		pending = {}
		return
	end
	SyncLocal()
end

function Stats.Shared()
	return ns.db and ns.db.sharedStats
end

function Stats.Receive(prefix, message, channel, sender)
	Receive(prefix, message, channel, sender)
end

ns.OnProgress(SyncLocal)
ns.On("PLAYER_LOGIN", function()
	SanitizeShared()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
	end
	SyncLocal()
end)
ns.On("PLAYER_ENTERING_WORLD", SyncLocal)
ns.On("GROUP_ROSTER_UPDATE", SyncLocal)
ns.On("GUILD_ROSTER_UPDATE", SyncLocal)
ns.On("PLAYER_GUILD_UPDATE", SyncLocal)
ns.On("CHAT_MSG_ADDON", Receive)

return Stats
