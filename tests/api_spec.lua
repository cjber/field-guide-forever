local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns
local API = harness.env.FieldGuideForever and harness.env.FieldGuideForever.API

assert(API, "the public API is installed")
assert(API.version >= 1, "the contract is versioned")
assert(API.version == 2 and API.minor == 3, "the tier ladder is API version 2, with size records in 2.3")

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
				[1001] = {
					count = 99,
					rare = -4,
					shiny = 4,
					kills = 8,
					sizeSmallest = 84,
					sizeLargest = 127,
					tiny = 1,
					giant = 2,
					injected = function() end,
				},
				[1002] = false,
				[1003] = { count = 3 },
			},
			encounters = "broken",
			unexpected = true,
			tracked = 1003,
		},
	},
})
assert(migrated.version == ns.SCHEMA, "version zero migrates forward")
local migratedEntry = migrated.chars["Old-Realm"].species[1001]
assert(migratedEntry.count == ns.Model.MASTERED_AT and migratedEntry.bronze == 8)
assert(migratedEntry.silver == 0 and migratedEntry.gold == 0 and migratedEntry.shiny == 1)
assert(migratedEntry.rare == nil and migratedEntry.injected == nil and migrated.chars["Old-Realm"].unexpected == nil)
assert(
	migratedEntry.sizeSmallest == 84
		and migratedEntry.sizeLargest == 127
		and migratedEntry.tiny == 1
		and migratedEntry.giant == 2,
	"size records survive a reload"
)
assert(migrated.chars["Old-Realm"].species[1002] == nil, "invalid entries are discarded")
assert(type(migrated.chars["Old-Realm"].encounters) == "table", "corrupt encounter data is repaired")
assert(migrated.chars["Old-Realm"].tracked == 1003, "the tracked species survives a reload")
local legacy = migrated.chars["Old-Realm"].species[1003]
assert(legacy.kills == 3 and legacy.killsEstimated, "kills taken from a save without them are marked as estimated")
assert(not migratedEntry.killsEstimated, "a save that counted kills keeps them exact")
legacy.sharedKillsBaseline = 3
legacy.kills = 5
local reloaded = ns.Migrate(migrated).chars["Old-Realm"].species[1003]
assert(reloaded.sharedKillsBaseline == 3, "the estimated-kill baseline survives a reload")
assert(reloaded.kills == 5, "reloading preserves observed kills after the baseline")
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

local function GuidFor(tier, salt, npcId)
	for index = 1, 1000000 do
		local guid = "Creature-0-1-0-1-" .. (npcId or 1001) .. "-" .. salt .. string.format("%010X", index)
		if ns.Model.SpawnTier(guid) == tier then
			return guid
		end
	end
	error("no GUID rolls " .. tier)
end

ns.Model.ClearSightings()
harness:Kill("Plainstrider", 1001, GuidFor("bronze", "api"))
local specimen = API.Specimen(1001)
assert(
	specimen and specimen.count == 1 and specimen.kills == 1 and specimen.rank == 1,
	"a recorded kill is visible through the API"
)
assert(specimen.firstKill == 1000 and specimen.firstSighting == 1000, "the API exposes local first records")
assert(specimen.bronze and not specimen.silver and not specimen.gold and not specimen.shiny, "a bronze spawn")
progress = API.Progress("The Barrens")
assert(progress.catalogued == 1, "the kill catalogues the species")

harness.Mock.units.nameplate1 = "Savannah Prowler"
harness:Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
local prowler = API.Specimen(1003)
assert(prowler and prowler.firstSighting == 1000, "a visible hostile nameplate records a personal first sighting")
assert(prowler.kills == 0, "a sighting alone does not count as a kill")

for _, tier in ipairs({ "silver", "gold", "shiny" }) do
	harness:Kill("Dishu", 1019, GuidFor(tier, "dishu", 1019))
end
local tiered = API.Specimen(1019)
assert(tiered and tiered.silverCount == 1 and tiered.goldCount == 1 and tiered.shinyCount == 1, "each coat counts")
assert(tiered.bestTier == "shiny", "the best coat is reported")
assert(
	type(tiered.sizeSmallest) == "number" and type(tiered.sizeLargest) == "number",
	"the API exposes the species' size records"
)
assert(tiered.sizeSmallest <= tiered.sizeLargest and tiered.tiny >= 0 and tiered.giant >= 0, "size records are ordered")

-- The detail page leads with the round portrait and the four ladder slots, read from the character's state.
ns.Detail.Create(harness.env.CreateFrame("Frame"))
local character = ns.GetCharacterState(false)
local detail = ns.Detail
detail.Show(ns.SpeciesById[1019], character, ns.SpeciesZone[1019])
local slots = detail.slots
assert(slots.bronze.Status:GetText() == "Every spawn", "an unfound bronze slot shows its odds")
assert(slots.silver.Title:GetText() == "Silver" and slots.silver.Status:GetText() == "Found 1", "silver is found")
assert(slots.gold.Status:GetText() == "Found 1", "gold is found")
assert(slots.shiny.Status:GetText() == "Found", "a found shiny reads Found")
local research = detail.specimenCount:GetText()
assert(research == "3 / 10 sightings", "the bar counts this species' sightings: " .. research)

assert(detail.location.template == "InsetFrameTemplate", "zone artwork has its own native border")
assert(detail.name:GetParent() == detail.content, "detail labels render above the content background")
local _, _, _, dishuDisplay = ns.CreatureInfo.Get(1019)
assert(detail.portrait.portraitDisplayID == dishuDisplay, "the portrait draws the selected NPC")
assert(detail.portrait:IsShown(), "the portrait is visible")
detail.Show(ns.SpeciesById[1019], character, ns.SpeciesZone[1019])
assert(detail.portrait.portraitDisplayID == dishuDisplay, "a refresh keeps the portrait")
assert(
	detail.recordsTitle:IsShown() and detail.records[1].key:GetText() == "Sightings",
	"records show as key and value pairs"
)
local recordKeys = {}
for _, row in ipairs(detail.records) do
	recordKeys[row.key:GetText()] = row.value:GetText()
end
assert(recordKeys.Largest and recordKeys.Smallest, "the records section keeps the size range")
assert(recordKeys.Largest:match("^%d+%.%d%dx$") and recordKeys.Smallest:match("^%d+%.%d%dx$"), "sizes read as 1.12x")
detail.Show(nil, nil, nil)
assert(not detail.portrait:IsShown(), "empty selection clears the portrait")
assert(
	not detail.slots.bronze:IsShown() and not detail.recordsTitle:IsShown() and not detail.mapButton:IsEnabled(),
	"empty selection clears the slots, records and map"
)
detail.Show(ns.SpeciesById[1001], character, ns.SpeciesZone[1001])
assert(detail.portrait:IsShown(), "new selection restores the portrait")
assert(slots.bronze.Status:GetText() == "Found 1", "Plainstrider's bronze spawn is found")
assert(slots.silver.Status:GetText() == "1 in 25 spawns", "a missing silver says its odds")
local originalAreaMaps = ns.QuestieDB.AreaMaps
ns.QuestieDB.AreaMaps = function()
	return { [17] = 1413, [38] = 1432 }, { [17] = 999 }
end
detail.Show(ns.SpeciesById[1001], character, ns.SpeciesZone[1001])
assert(detail.locationArt._texture == ns.Art.LOCATION_ART[17], "the location uses native zone artwork")
assert(detail.mapButton:IsEnabled(), "a resolved map enables navigation")
detail.mapButton:GetScript("OnClick")()
assert(harness.Mock.openedMap == 999, "map navigation respects QuestieDB overrides")
ns.QuestieDB.AreaMaps = function()
	return { [17] = 1413 }, { [17] = 0 }
end
detail.Show(ns.SpeciesById[1001], character, ns.SpeciesZone[1001])
assert(not detail.mapButton:IsEnabled() and not detail.mapButton:IsShown(), "zero map override suppresses navigation")
ns.QuestieDB.AreaMaps = originalAreaMaps
detail.Show(ns.SpeciesById[1001], character, { id = -1, name = "Unknown", species = {} })
assert(
	not detail.locationArt:IsShown() and not detail.location:IsShown(),
	"missing art leaves no stale picture or frame"
)
assert(not detail.mapButton:IsEnabled(), "an unresolved location disables old map navigation")

-- Header totals count species with each coat found.
local totals = ns.Model.TierTotals(character, { ns.SpeciesById[1001], ns.SpeciesById[1019] })
assert(totals.silver == 1 and totals.gold == 1 and totals.shiny == 1, "each coat counts one species")

harness:Kill("Plainstrider", 1001, GuidFor("shiny", "plainstrider"))
specimen = API.Specimen(1001)
assert(specimen.shiny and specimen.shinyCount == 1, "a shiny spawn is visible as a shiny")

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
local bossLine = API.Sightings()[1]
assert(bossLine.species == "Example Boss" and bossLine.zone == "Test Instance", "a boss kill is logged in its instance")
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
local ownStore = harness.env.FieldGuideForeverDB.peerStats[ns.CharacterKey()].fieldguide
for _ in pairs(ownStore) do
	peerCount = peerCount + 1
end
assert(peerCount <= 100, "shared peer storage is bounded")
for index = 1, 513 do
	harness:Fire("CHAT_MSG_ADDON", "WFAStats", "1|fieldguide|creature_kills|" .. index .. "|1|900", "GUILD", "CapPeer1")
end
local rowCount = 0
for _ in pairs(ownStore.CapPeer1 and ownStore.CapPeer1.creature_kills or {}) do
	rowCount = rowCount + 1
end
assert(rowCount <= 512, "shared subject rows per peer are bounded")

harness.Mock.inGuild = true
harness:Fire("GROUP_ROSTER_UPDATE")
harness:RunTimers()
harness:RunTimers()
local sent = harness.Mock.sentAddonMessages[1]
assert(
	sent and sent.prefix == "WFAStats" and sent.channel == "GUILD",
	"local progress broadcasts on the shared guild channel"
)
assert(
	sent.message:match("^1|fieldguide|[%a_]+|[%w_]+|%d+|%d+$"),
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
local personalBoard = API.Leaderboard("creature_kills", "1001")
assert(
	personalBoard and #personalBoard == 1 and personalBoard[1].source == "local",
	"opting out hides peers on an individual board while preserving the personal row"
)
local state = ns.GetCharacterState(false)
local entry = state.species[1001]
local beforeTotal = localOnly[1].value
entry.kills = entry.kills + 100
entry.sharedKillsBaseline = 100
entry.killsEstimated = true
assert(API.LeaderboardSummary()[1].value == beforeTotal, "summary subtracts the same historical baseline as sharing")
assert(API.Leaderboard("creature_kills", "1001")[1].value == 2, "individual boards use observed kills too")
entry.kills = entry.kills - 100
entry.sharedKillsBaseline = nil
entry.killsEstimated = nil

local unknownZone = API.Progress("Nowhere")
assert(unknownZone == nil, "an unknown zone has no answer")
assert(API.Specimen(999999) == nil, "an unknown species has no answer")

local listParent = harness.env.CreateFrame("Frame")
listParent:SetSize(330, 514)
ns.List.Create(listParent, { Select = function() end })
ns.List.scroll:SetHeight(514)
local listEntries = {}
for index = 1, 30 do
	listEntries[index] = { species = ns.SpeciesById[1001], state = {} }
end
ns.List.Refresh(listEntries, 1001)
ns.List.scroll:SetVerticalScroll(400)
ns.List.Refresh(listEntries, 1001, true)
assert(ns.List.scroll:GetVerticalScroll() == 400, "progress refresh preserves the list scroll position")
while #listEntries > 12 do
	table.remove(listEntries)
end
ns.List.Refresh(listEntries, 1001, true)
assert(ns.List.scroll:GetVerticalScroll() == 12 * 55 - 502, "a shorter list clamps scrolling to its new end")
ns.List.Refresh(listEntries, 1001)
assert(ns.List.scroll:GetVerticalScroll() == 0, "changing the list resets scrolling")
ns.List.scroll:SetVerticalScroll(30)
ns.List.Refresh({}, nil, true)
assert(ns.List.scroll:GetVerticalScroll() == 0, "an empty list returns scrolling to zero")

print("api: ok")
