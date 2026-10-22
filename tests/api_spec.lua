local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns
local API = harness.env.FieldGuideForever and harness.env.FieldGuideForever.API

assert(API, "the public API is installed")
assert(API.version >= 1, "the contract is versioned")
assert(API.version == 1 and API.minor == 1, "the spawn additions are API minor 1")

local npcFixture = {
	[1001] = {
		name = "Plainstrider",
		minLevel = 1,
		maxLevel = 2,
		rank = 0,
		subName = "Beast",
		zoneID = 17,
		spawns = { [17] = {} },
	},
	[1003] = {
		name = "Savannah Prowler",
		minLevel = 9,
		maxLevel = 10,
		rank = 0,
		subName = "Beast",
		zoneID = 17,
		spawns = { [17] = {} },
	},
	[1019] = {
		name = "Dishu",
		minLevel = 13,
		maxLevel = 13,
		rank = 2,
		subName = "Beast",
		zoneID = 17,
		spawns = { [17] = {} },
	},
}
harness.env.LibQuestieDB = {
	Npc = {
		GetAllIds = function()
			return { 1001, 1003, 1019 }
		end,
		GetAll = function(id, fields)
			local row, values = npcFixture[id], {}
			for _, field in ipairs(fields) do
				values[#values + 1] = row[field]
			end
			return values
		end,
	},
}

assert(API.Species("The Barrens") == nil, "before initialisation there is no answer")
assert(API.Progress("The Barrens") == nil, "progress is unknown before initialisation")
assert(API.Specimen(1001) == nil, "a specimen is unknown before initialisation")
assert(not API.Ready(), "not ready before the saved variables load")

harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:RunTimers()
assert(ns.ready, "the addon initialises on its own ADDON_LOADED")
assert(harness.env.FieldGuideForeverDB.version == ns.SCHEMA, "the database is upgraded to the current schema")
assert(harness.env.FieldGuideForeverDB.options.statsShare == true, "sharing defaults on with an opt-out setting")
assert(API.Ready(), "the API answers after initialisation")

local migrated = ns.Migrate({
	version = 0,
	chars = {
		["Old-Realm"] = {
			species = {
				[1001] = { count = 99, rare = -4, shiny = 4, kills = 8, injected = function() end },
				[1002] = false,
			},
			encounters = "broken",
			unexpected = true,
		},
	},
})
assert(migrated.version == ns.SCHEMA, "version zero migrates forward")
local migratedEntry = migrated.chars["Old-Realm"].species[1001]
assert(migratedEntry.count == ns.Model.MASTERED_AT and migratedEntry.rare == 0 and migratedEntry.shiny == 1)
assert(migratedEntry.injected == nil and migrated.chars["Old-Realm"].unexpected == nil)
assert(migrated.chars["Old-Realm"].species[1002] == nil, "invalid entries are discarded")
assert(type(migrated.chars["Old-Realm"].encounters) == "table", "corrupt encounter data is repaired")
local empty = ns.Migrate(false)
assert(empty.version == ns.SCHEMA and type(empty.chars) == "table", "corrupt root data becomes valid empty state")

harness:Fire("PLAYER_LOGIN")
assert(harness.Mock.registeredPrefix == "WFAStats", "the shared stats prefix is registered")

local species = API.Species("The Barrens")
assert(species and #species == 3, "the QuestieDB fixture catalogue is readable")
assert(species[1].zone == "The Barrens" and species[1].name ~= "", "species carry shared facts")

local progress = API.Progress("The Barrens")
assert(progress and progress.total == #species, "the API counts the same catalogue")
assert(progress.catalogued == 0 and progress.fraction == 0, "an empty catalogue has no progress")

ns.Model.ClearSightings()
ns.Model.SetRandom(function()
	return 1
end)
harness:Kill("Plainstrider")
local specimen = API.Specimen(1001)
assert(
	specimen and specimen.count == 1 and specimen.kills == 1 and specimen.rank == 1,
	"a recorded kill is visible through the API"
)
assert(specimen.firstKill == 1000 and specimen.firstSighting == 1000, "the API exposes local first records")
assert(not specimen.shiny and not specimen.rare, "an ordinary kill is neither rare nor shiny")
progress = API.Progress("The Barrens")
assert(progress.catalogued == 1, "the kill catalogues the species")

harness.Mock.units.nameplate1 = "Savannah Prowler"
harness:Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
local prowler = API.Specimen(1003)
assert(prowler and prowler.firstSighting == 1000, "a visible hostile nameplate records a personal first sighting")
assert(prowler.kills == 0, "a sighting alone does not count as a kill")

for _ = 1, ns.Model.RARE_TARGET do
	harness:Kill("Dishu")
end
local rare = API.Specimen(1019)
assert(rare and rare.rareCount == ns.Model.RARE_TARGET and rare.rare, "rare sightings reach the variant target")

ns.Model.SetRandom(function()
	return 0
end)
harness:Kill("Plainstrider")
specimen = API.Specimen(1001)
assert(specimen.shiny and specimen.shinyCount == 1, "a lucky roll is visible as a shiny")

local sightings = API.Sightings()
assert(sightings and #sightings >= 1, "the session log is exposed")
assert(sightings[1].species == "Plainstrider" and sightings[1].kind == "shiny", "newest sighting first")

harness:Fire("ENCOUNTER_START", 77, "Example Boss", 2, 5)
harness:Fire("ENCOUNTER_END", 77, "Example Boss", 2, 5, 1)
harness:Fire("ENCOUNTER_END", 77, "Example Boss", 3, 5, 1)
local encounters = API.Encounters()
assert(encounters and #encounters == 1 and encounters[1].kills == 2, "successful encounter records are public")
assert(encounters[1].firstDifficulty == 2 and encounters[1].difficulties["3"] == 1, "encounter difficulties are kept")
assert(
	encounters[1].sightings == 1 and encounters[1].firstSighting == 1000,
	"encounter start records a personal sighting"
)
harness:Fire("ENCOUNTER_END", 78, "Wiped Boss", 2, 5, 0)
assert(#API.Encounters() == 1, "failed encounters never count as boss kills or entries")

harness:Fire("CHAT_MSG_ADDON", "WFAStats", "1|fieldguide|creature_kills|1001|7|900", "GUILD", "Peer-Realm")
harness:Fire("CHAT_MSG_ADDON", "WFAStats", "1|fieldguide|creature_kills|1001|5|950", "GUILD", "Peer-Realm")
harness:Fire("CHAT_MSG_ADDON", "WFAStats", "1|fieldguide|first_sighting|1001|1|850", "GUILD", "Peer-Realm")
harness:Fire("CHAT_MSG_ADDON", "WFAStats", "1|spf|distance_yards|42|12345|900", "GUILD", "Peer-Realm")
harness:Fire("CHAT_MSG_ADDON", "WFAStats", "1|spf|first_route|42|1|800", "GUILD", "Peer-Realm")
harness:Fire("CHAT_MSG_ADDON", "WFAStats", "1|spf|distance_travelled|43|12345|900", "GUILD", "Peer-Realm")
harness:Fire("CHAT_MSG_ADDON", "WFAStats", "1|unknown|distance_travelled|42|12345|900", "GUILD", "Peer-Realm")
local shared = API.SharedStats()
assert(shared["Peer-Realm"].fieldguide["1001"].creature_kills.value == 7, "shared counters merge by maximum")
assert(shared["Peer-Realm"].fieldguide["1001"].first_sighting.time == 850, "shared firsts keep the earliest time")
assert(shared["Peer-Realm"].spf["42"].distance_yards.value == 12345, "other suite addon metrics are stored")
assert(shared["Peer-Realm"].spf["42"].first_route == nil, "unknown metrics are rejected for a known addon")
assert(shared["Peer-Realm"].spf["43"] == nil, "deprecated metric IDs are rejected")
assert(shared["Peer-Realm"].unknown == nil, "unrecognized addon tokens are ignored")
local board = API.Leaderboard("creature_kills", "1001")
assert(board and board[1].player == "Peer-Realm" and board[1].value == 7, "peer progress is exposed as a ranked record")
assert(board[2].source == "local" and board[2].value == 2, "the same board includes local character records")
local summary = API.LeaderboardSummary()
assert(
	summary[1].source == "reported" and summary[1].value == 7,
	"the leaderboard summary labels peer totals as reports"
)

for index = 1, 101 do
	local peer = "CapPeer" .. index
	harness:Fire("CHAT_MSG_ADDON", "WFAStats", "1|fieldguide|creature_kills|1001|1|900", "GUILD", peer)
end
local peerCount = 0
for _ in pairs(harness.env.FieldGuideForeverDB.sharedStats) do
	peerCount = peerCount + 1
end
assert(peerCount <= 100, "shared peer storage is bounded")
for index = 1, 513 do
	harness:Fire("CHAT_MSG_ADDON", "WFAStats", "1|fieldguide|creature_kills|" .. index .. "|1|900", "GUILD", "CapPeer1")
end
local rowCount = 0
for _ in pairs(harness.env.FieldGuideForeverDB.sharedStats.CapPeer1.fieldguide) do
	rowCount = rowCount + 1
end
assert(rowCount <= 512, "shared subject rows per peer are bounded")

harness.Mock.inGuild = true
harness:Fire("GROUP_ROSTER_UPDATE")
harness:RunTimers()
local sent = harness.Mock.sentAddonMessages[1]
assert(
	sent and sent.prefix == "WFAStats" and sent.channel == "GUILD",
	"local progress broadcasts on the shared guild channel"
)
assert(
	sent.message:match("^1|fieldguide|[%a_]+|[%d_]+|%d+|%d+$"),
	"outbound messages match the shared versioned schema"
)
ns.Stats.SetEnabled(false)
ns.db.options.statsShare = false
assert(API.SharedStats() == nil, "opt-out disables peer exchange and shared leaderboard reads")
local localOnly = API.LeaderboardSummary()
assert(
	localOnly and #localOnly == 1 and localOnly[1].source == "local",
	"the local leaderboard remains available after opt-out"
)

local unknownZone = API.Progress("Nowhere")
assert(unknownZone == nil, "an unknown zone has no answer")
assert(API.Specimen(999999) == nil, "an unknown species has no answer")

print("api: ok")
