local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns
local API = harness.env.FieldGuideForever and harness.env.FieldGuideForever.API

assert(API, "the public API is installed")
assert(API.version >= 1, "the contract is versioned")
assert(API.version == 3 and API.minor == 7, "version 3 drops the leaderboard reads and Stats keeps its own totals")
assert(harness.env.ForeverCore.APIKit ~= nil, "the shared API kit is available at load")
assert(type(API.Subscribe) == "function", "the API subscribes through the shared kit")

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
	RequireContract = function()
		return true
	end,
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

local speciesBefore, speciesReason = API.Species("The Barrens")
assert(speciesBefore == nil and speciesReason == "loading", "before initialisation there is no answer: loading")
local progressBefore, progressReason = API.Progress("The Barrens")
assert(progressBefore == nil and progressReason == "loading", "progress is unknown before initialisation")
local specimenBefore, specimenReason = API.Specimen(1001)
assert(specimenBefore == nil and specimenReason == "loading", "a specimen is unknown before initialisation")
local trackedBefore, trackedReason = API.TrackedSpecies()
assert(trackedBefore == nil and trackedReason == "loading", "the tracked species is unknown before initialisation")
assert(API.SetTrackedSpecies(1001) == false, "setting a tracked species before the state exists changes nothing")
assert(not API.Ready(), "not ready before the saved variables load")

harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:RunTimers()
assert(ns.ready, "the addon initialises on its own ADDON_LOADED")
assert(harness.env.FieldGuideForeverDB.version == ns.SCHEMA, "the database is upgraded to the current schema")
assert(API.Ready(), "the API answers after initialisation")

-- Stats is the suite's activity shape over the metrics the addon counts: one local all-subject total per metric, with
-- no invented event time before anything has happened.
local freshStats = API.Stats()
assert(type(freshStats) == "table" and #freshStats == 15, "Stats has one row for every metric the addon counts")
local freshByMetric = {}
for _, row in ipairs(freshStats) do
	assert(
		row.addon == "FieldGuideForever" and row.subject == "all",
		"an activity row names the addon and an all subject"
	)
	freshByMetric[row.metric] = row
end
assert(
	freshByMetric.creature_kills.value == 0 and freshByMetric.creature_kills.eventUnix == nil,
	"an empty metric leaves its event time out"
)

-- The tracked species is the saved switch the shared column follows, and the API writes the same one.
assert(API.TrackedSpecies() == nil, "a fresh character tracks nothing")
local notTracked, notTrackedReason = API.TrackedSpecies()
assert(notTracked == nil and notTrackedReason == "none", "nothing tracked has nothing to answer")
assert(API.SetTrackedSpecies(1001) == true, "the API tracks a catalogue species")
assert(API.TrackedSpecies() == 1001, "the API reads the species it set")
assert(ns.Tracker.TrackedSpecies() == 1001, "the tracker section follows the same species")
assert(ns.GetCharacterState(false).tracked == 1001, "the tracked switch is saved")
assert(API.SetTrackedSpecies(1001) == false, "setting the species already tracked changes nothing")
assert(API.SetTrackedSpecies(999999) == false, "an unknown species id is refused")
assert(ns.Tracker.TrackedSpecies() == 1001, "a refused id leaves the tracker alone")
assert(API.SetTrackedSpecies(1001.5) == false, "a malformed species id is refused")
assert(API.SetTrackedSpecies(nil) == true, "nil clears the tracked species")
assert(API.TrackedSpecies() == nil, "nothing is tracked after clearing")
assert(API.SetTrackedSpecies(nil) == false, "clearing nothing changes nothing")

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
-- A save written while spawn sizes existed (#153) loads cleanly and loses every size field.
local sized = ns.Migrate({
	version = ns.SCHEMA,
	chars = {
		["Sized-Realm"] = {
			species = {
				[1001] = {
					count = 1,
					kills = 1,
					sizeSmallest = 65,
					sizeLargest = 145,
					tiny = 1,
					giant = 1,
				},
			},
		},
	},
})
local sizedEntry = sized.chars["Sized-Realm"].species[1001]
assert(sizedEntry.count == 1 and sizedEntry.kills == 1, "the rest of a sized save survives")
assert(
	sizedEntry.sizeSmallest == nil
		and sizedEntry.sizeLargest == nil
		and sizedEntry.tiny == nil
		and sizedEntry.giant == nil,
	"a save with spawn sizes loads cleanly and drops them"
)
local empty = ns.Migrate(false)
assert(empty.version == ns.SCHEMA and type(empty.chars) == "table", "corrupt root data becomes valid empty state")

harness:Fire("PLAYER_LOGIN")

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

-- A unit token reads the tier of its GUID, exactly as the target frame and nameplate art do. A player and a unit the
-- player cannot attack have no spawn tier rather than the bronze the art falls back to.
local targetGuid = GuidFor("gold", "spawn-tier")
harness.Mock.units.target = "Plainstrider"
harness.Mock.guids.target = targetGuid
assert(API.SpawnTier("target") == "gold", "a hostile unit reads the tier of its GUID")
harness.Mock.players.target = true
local playerTier, playerTierReason = API.SpawnTier("target")
assert(playerTier == nil and playerTierReason == "none", "a player has no spawn tier")
harness.Mock.players.target = nil
harness.Mock.canAttack.target = false
local friendlyTier, friendlyTierReason = API.SpawnTier("target")
assert(friendlyTier == nil and friendlyTierReason == "none", "a unit the player cannot attack has no spawn tier")
harness.Mock.canAttack.target = nil
local badUnit, badUnitReason = API.SpawnTier(nil)
assert(badUnit == nil and badUnitReason == "none", "a missing unit token has no spawn tier")

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
assert(recordKeys.Sightings and recordKeys["Best variant"], "the records section keeps its progress rows")
assert(recordKeys.Largest == nil and recordKeys.Smallest == nil, "size records are gone from the Records section")
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
assert(
	harness.Mock.openedMap == 999 and harness.Mock.refusedMapOpeners == nil,
	"map navigation respects QuestieDB overrides through the secure opener"
)
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

-- Stats is this character's own totals: one all-subject row per metric the addon counts, with the latest real event
-- time and no time on a metric that has not happened.
local activity = API.Stats()
local activityByMetric = {}
for _, row in ipairs(activity) do
	assert(row.addon == "FieldGuideForever" and row.subject == "all", "every activity row is an all-subject total")
	activityByMetric[row.metric] = row
end
assert(activityByMetric.creature_kills.value == 5, "Stats counts every observed kill")
assert(activityByMetric.creature_kills.eventUnix == 1000, "the latest kill time is the row's event time")
assert(
	activityByMetric.gold_finds.value == 1 and activityByMetric.first_gold.value == 1,
	"Stats totals each coat and its first"
)
assert(activityByMetric.shiny_finds.value == 2, "Stats adds a coat across species")
assert(
	activityByMetric.boss_kills.value == 2 and activityByMetric.boss_kills.eventUnix == 1000,
	"boss kills total every difficulty of the encounter"
)

-- Forever Leaderboards is gone: a save from a version that shared progress drops its peer tables and setting on load.
local stripped = ns.Migrate({
	version = 2,
	chars = {},
	options = { statsShare = false },
	peerStats = { ["Peer-Realm"] = { fieldguide = {} } },
	sharedStats = { ["Peer-Realm"] = { fieldguide = {} } },
})
assert(stripped.peerStats == nil and stripped.sharedStats == nil, "the dead peer tables are dropped on load")
assert(stripped.options.statsShare == nil, "the removed sharing setting is dropped on load")

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

-- Subscribe is ForeverCore's shared hub: a fresh character hears the frame after the change, once per burst, with
-- only the channels that changed. Core bumps the counters where a record is first produced, so the toast setting
-- cannot hide them.
local subscribed = Mock.Harness()
subscribed.env.LibQuestieDB = {
	RequireContract = function()
		return true
	end,
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
subscribed:Fire("ADDON_LOADED", "FieldGuideForever")
subscribed:Fire("PLAYER_LOGIN")
subscribed:RunTimers()
local eventAPI = subscribed.env.FieldGuideForever.API

local heard = {}
local unsubscribe = eventAPI.Subscribe(function(changes)
	heard[#heard + 1] = changes
end)
assert(type(unsubscribe) == "function", "Subscribe returns an unsubscribe function")
subscribed:Kill("Plainstrider", 1001, GuidFor("gold", "subscribed"))
subscribed:RunTimers()
assert(#heard == 1, "one burst sends one call")
assert(heard[1].tier == true, "a first gold raises the tier channel")
assert(heard[1].sighting == true and heard[1].specimen == true, "the first kill also raises sighting and specimen")
unsubscribe()
unsubscribe()
subscribed:Kill("Savannah Prowler", 1003, GuidFor("gold", "unsubscribed", 1003))
subscribed:RunTimers()
assert(#heard == 1, "an unsubscribed callback hears nothing, and unsubscribing twice is safe")

local zoneHeard
local unsubscribeZone = eventAPI.Subscribe(function(changes)
	zoneHeard = changes
end)
subscribed:Kill("Dishu", 1019, GuidFor("gold", "zone", 1019))
subscribed:RunTimers()
assert(zoneHeard and zoneHeard.zone == true, "the kill that completes a zone raises the zone channel")
unsubscribeZone()

local trackedHeard
local unsubscribeTracked = eventAPI.Subscribe(function(changes)
	trackedHeard = changes
end)
assert(eventAPI.SetTrackedSpecies(1001) == true)
subscribed:RunTimers()
assert(trackedHeard and trackedHeard.tracked == true, "the tracked switch reaches subscribers")
unsubscribeTracked()

-- Discovery: the addon hands its API to ForeverCore's suite registry once, so another addon can list every Forever
-- addon. A core whose kit predates Publish (minor 1) still loads, with nothing published and no error.
local listed
for _, addonEntry in ipairs(harness.env.ForeverCore.APIKit.Addons()) do
	if addonEntry.name == "FieldGuideForever" then
		listed = addonEntry
	end
end
assert(listed ~= nil, "the API is listed by ForeverCore.APIKit.Addons()")
assert(listed.api == API, "the listed entry is this addon's own API table")
assert(listed.version == API.version and listed.minor == API.minor, "the listing carries the API's version and minor")

local beforeAPI = {}
for _, file in ipairs(Mock.TocFiles()) do
	if file == "Core/API.lua" then
		break
	end
	beforeAPI[#beforeAPI + 1] = file
end
local oldKitHarness = Mock.Harness({ files = beforeAPI })
local oldKit = oldKitHarness.env.ForeverCore.APIKit
local publishCalls = {}
oldKit.minor = 1
oldKit.Publish = function(name)
	publishCalls[#publishCalls + 1] = name
end
local loaded, loadError = pcall(oldKitHarness.Load, "Core/API.lua")
assert(loaded, "a kit at minor 1 still loads the API: " .. tostring(loadError))
assert(#publishCalls == 0, "a kit at minor 1 is never asked to publish")

print("api: ok")
