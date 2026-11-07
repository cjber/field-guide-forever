-- Adapter integration: persistence, independent subscribers, snapshots and cancellation use the TOC-loaded code.
local Mock = dofile("tests/wow_mock.lua")
local checks = 0
local function check(value, message)
	checks = checks + 1
	assert(value, message)
end
local function start(saved)
	local h = Mock.Harness()
	h.env.FieldGuideForeverDB = saved
	h:Fire("ADDON_LOADED", "FieldGuideForever")
	h.ns.catalogueStatus = "ok"
	return h, h.ns
end
local function tick(h, seconds)
	Mock.clock = Mock.clock + (seconds or 1)
	h:RunTimers()
end

local optedOut, ns = start({
	version = 2,
	chars = { ["Tester-TestRealm"] = { species = { [42] = { count = 3 } } } },
	options = { statsShare = false },
	sharedStats = {
		["Alice-Other"] = {
			fieldguide = {
				["42"] = {
					creature_kills = { value = 8, time = 900 },
					first_sighting = { value = 1, time = 800 },
				},
			},
		},
	},
})
check(ns.db.options.statsShare == false, "a saved opt-out survives migration")
Mock.inGuild, Mock.inGroup = true, true
local disabledSends = #Mock.sentAddonMessages
ns.FireProgress()
optedOut:Fire("PLAYER_ENTERING_WORLD")
optedOut:Fire("GROUP_ROSTER_UPDATE")
optedOut:Fire("PLAYER_GUILD_UPDATE")
for _ = 1, 5 do
	tick(optedOut)
end
check(#Mock.sentAddonMessages == disabledSends, "saved opt-out suppresses progress and membership sends")

check(ns.db.sharedStats == nil, "the account-wide cache is consumed once")
local entry = ns.GetCharacterState().species[42]
check(entry.sharedKillsBaseline == 3, "migration seeds estimated history before any new observation")
entry.kills = entry.kills + 2
check(ns.Model.ObservedKills(entry) == 2, "observations while opted out remain personal progress")
local again = ns.Migrate(ns.db)
check(again.chars[ns.CharacterKey()].species[42].sharedKillsBaseline == 3, "reload retains the baseline")
check(next(ns.Stats.Shared()) == nil, "cached peers are hidden while opted out")
ns.db.options.statsShare = true
ns.Stats.SetEnabled(true)
local shared = ns.Stats.Shared()
check(shared["Alice-Other"].fieldguide["42"].creature_kills.value == 8, "migration transposes legacy counters")
check(shared["Alice-Other"].fieldguide["42"].first_sighting.time == 800, "migration preserves event times")
ns.db.peerStats["Another-Realm"] = { fieldguide = {} }
local oldKey = ns.CharacterKey
ns.CharacterKey = function()
	return "Another-Realm"
end
check(next(ns.Stats.Shared()) == nil, "peer caches belong to the receiving character")
ns.CharacterKey = oldKey
check(ns.Stats.Shared()["Alice-Other"] ~= nil, "switching back retains that character's reports")

local h
h, ns = start()
Mock.inGuild, Mock.inGroup = true, true
local actualStore = {}
local source = ns.PeerStats.New({
	addon = "spf",
	enabled = function()
		return true
	end,
	db = function()
		return actualStore
	end,
	metrics = { distance_yards = { subject = "all" } },
	snapshot = function()
		return { { metric = "distance_yards", subject = "all", value = 55, eventUnix = 1000 } }
	end,
})
check(source:Sync() == 2, "Field Guide's reader leaves the source sender alive on both channels")
h:Fire("CHAT_MSG_ADDON", "WFAStats", "1|spf|distance_yards|all|72|900", "GUILD", "Alice-Other")
check(actualStore["Alice-Other"].distance_yards.all.value == 72, "the source receives its report")
check(ns.API.SharedStats()["Alice-Other"].spf.all.distance_yards.value == 72, "the reader independently exposes it")
h:Fire("CHAT_MSG_ADDON", "WFAStats", "1|fieldguide|creature_kills|42|2|900", "GUILD", "Alice-Other")
h:Fire("CHAT_MSG_ADDON", "WFAStats", "1|fieldguide|creature_kills|all|99|900", "GUILD", "Alice-Other")
check(ns.API.LeaderboardSummary()[1].value == 99, "summary uses the full total without double-counting details")
for _, name in ipairs({ "Zed-Other", "Amy-Other" }) do
	h:Fire("CHAT_MSG_ADDON", "WFAStats", "1|fieldguide|first_sighting|42|1|800", "GUILD", name)
end
local board = ns.API.Leaderboard("first_sighting", "42")
check(board[1].player == "Amy-Other" and board[2].player == "Zed-Other", "equal first records sort by player")

local state = ns.GetCharacterState()
for id = 1, 300 do
	state.species[id] = { kills = 2, count = 2, lastKill = 1000 }
end
ns.FireProgress()
for _ = 1, 3 do
	tick(h)
end
Mock.inGroup = false
h:Fire("GROUP_ROSTER_UPDATE")
for _ = 1, 200 do
	tick(h)
end
local aggregate, detailCount, sourceSends = nil, 0, 0
for _, sent in ipairs(Mock.sentAddonMessages) do
	if sent.channel == "GUILD" then
		if sent.message:match("^1|spf|") then
			sourceSends = sourceSends + 1
		end
		local total = sent.message:match("^1|fieldguide|creature_kills|all|(%d+)|")
		if total then
			aggregate = tonumber(total)
		end
		if sent.message:match("^1|fieldguide|creature_kills|%d+|") then
			detailCount = detailCount + 1
		end
	end
end
check(aggregate == 600, "guild delivery continues after the group disappears and includes every species")
check(detailCount <= 127, "one snapshot bounds detail reports to leave room for other addons")
check(sourceSends > 0, "the real source still sends alongside Field Guide")
local personalTotal
for _, row in ipairs(ns.API.Leaderboard("creature_kills", "all")) do
	if row.source == "local" then
		personalTotal = row.value
	end
end
check(personalTotal == 600, "aggregate boards include the player's full observed total")
local unchanged = #Mock.sentAddonMessages
ns.FireProgress()
for _ = 1, 5 do
	tick(h)
end
check(#Mock.sentAddonMessages == unchanged, "unchanged snapshots do not resend totals")

state.species[1].kills = 3
ns.FireProgress()
h:RunTimers()
local spec = ns.Leaderboards and ns.Leaderboards.boards.fieldguide
check(spec ~= nil, "the shared Forever Leaderboards window is published")
check(spec.title == "Field Guide Forever", "the tab carries the addon's title")
check(spec.metric == "Creature kills", "the board names its metric")
check(spec.icon == "Interface\\AddOns\\FieldGuideForever\\media\\Icon", "the tab carries the addon's icon")
check(type(spec.revision) == "function", "the board has a revision callback")
check(spec.sharing() == true, "sharing reads the addon's on setting")
local all = spec.board("all")
local own
for _, row in ipairs(all) do
	if row.you then
		own = row
	end
end
check(own and own.value == 601, "the all-time board ranks the player's observed kills")
check(own.class == nil, "rows leave class for the shared window to resolve")
local alice
for _, row in ipairs(all) do
	if row.name == "Alice" then
		alice = row
	end
end
check(alice and alice.value == 99, "the all-time board ranks a peer's reported total")
check(alice.class == nil, "a peer's class stays unknown")
local revision = spec.revision()
spec.board("week")
h:Fire("CHAT_MSG_ADDON", "WFAStats", "1|fieldguide|creature_kills|all|120|900", "GUILD", "Alice-Other")
h:RunTimers()
check(spec.revision() > revision, "a new peer row moves the board's revision")
local weekly = spec.board("week")
check(weekly[1].name == "Alice" and weekly[1].value == 21, "the weekly board ranks progress since the reset")
check(weekly[1].extra == "120 total", "the weekly row keeps the cumulative total in grey")
local opened
ns.Leaderboards.Open = function(_, key)
	opened = key
end
h.env.SlashCmdList.FIELDGUIDEFOREVER("leaderboard")
check(opened == "fieldguide", "the leaderboard command opens the shared window on this addon's tab")
ns.db.options.statsShare = false
ns.Stats.SetEnabled(false)
local before = #Mock.sentAddonMessages
for _ = 1, 5 do
	tick(h)
end
check(#Mock.sentAddonMessages == before, "opt-out cancels Field Guide's outstanding sends")
check(ns.API.SharedStats() == nil, "opt-out hides reader reports")
check(
	not ns.Stats.Receive("WFAStats", "1|fieldguide|creature_kills|42|1000|900", "GUILD", "Bob-Other"),
	"opt-out ignores incoming rows"
)
check(ns.API.LeaderboardSummary()[1].value == 601, "opt-out preserves personal history")
print(("stats: %d checks passed"):format(checks))
