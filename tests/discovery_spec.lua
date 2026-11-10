-- What a kill shows (UI/Discovery.lua): a first kill's explored-area line, New tag and minimap button pulse, the
-- achievement toast for silver, gold, shiny, mastery and zone milestones, the burst cap, the toast's click and both
-- settings.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")

local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

local npcFixture = {
	[1001] = { name = "Plainstrider", minLevel = 1, maxLevel = 2, rank = 0, subName = "Beast", zoneID = 17 },
	[1003] = { name = "Savannah Prowler", minLevel = 9, maxLevel = 10, rank = 0, subName = "Beast", zoneID = 17 },
	[1019] = { name = "Dishu", minLevel = 13, maxLevel = 13, rank = 2, subName = "Beast", zoneID = 17 },
}

local PAGE_TURN, ACHIEVEMENT = 836, 12891

-- UI/Window.lua's journal needs the client's portrait frame, which the mock does not draw. This stand-in keeps the
-- calls Discovery makes and builds the real list and detail panes inside a plain frame.
local function FakeWindow(ns)
	local Window = { shown = false }
	local parent
	function Window.Refresh()
		local entries = {}
		local state = ns.GetCharacterState(false)
		for _, species in ipairs(ns.Zones[Window.zoneIndex or 1].species) do
			entries[#entries + 1] = { species = species, state = state and state.species[species.id] }
		end
		ns.List.Refresh(entries, Window.selected)
	end
	function Window.Show()
		if not parent then
			parent = Mock.CreateFrame("Frame")
			ns.Detail.Create(parent)
			ns.List.Create(parent, { Select = Window.SelectSpecies })
		end
		Window.shown = true
		Window.Refresh()
	end
	function Window.Hide()
		Window.shown = false
	end
	function Window.IsShown()
		return Window.shown
	end
	function Window.SetTab(key)
		Window.tab = key
	end
	function Window.SelectZone(index)
		Window.zoneIndex = index
	end
	function Window.SelectSpecies(id)
		Window.selected = id
		ns.Detail.Show(ns.SpeciesById[id], ns.GetCharacterState(false), ns.SpeciesZone[id])
	end
	return Window
end

local files = {}
for _, file in ipairs(Mock.TocFiles()) do
	if file ~= "UI/Window.lua" then
		files[#files + 1] = file
	end
end

---@param options? table saved options to start with
local function Start(options)
	local ns = {}
	ns.Window = FakeWindow(ns)
	local harness = Mock.Harness({ ns = ns, files = files })
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
					values[#values + 1] = field == "spawns" and { [17] = {} } or row[field]
				end
				return values
			end,
		},
	}
	harness.env.FieldGuideForeverDB = { options = options or {} }
	harness:Fire("ADDON_LOADED", "FieldGuideForever")
	harness:Fire("PLAYER_LOGIN")
	harness:RunTimers()
	assert(harness.ns.ready and harness.ns.SpeciesById[1019], "the addon loads the fixture catalogue")
	Mock.sounds, Mock.messages, Mock.alerts = {}, {}, {}
	-- The toast template's Shield child needs Blizzard_AchievementUI loaded, so record the order the subsystem is
	-- registered in relative to the UI's own loader.
	local calls = {}
	harness.env.AchievementFrame_LoadUI = function()
		calls[#calls + 1] = "load"
	end
	local addSubSystem = harness.env.AlertFrame.AddQueuedAlertFrameSubSystem
	harness.env.AlertFrame.AddQueuedAlertFrameSubSystem = function(...)
		calls[#calls + 1] = "system"
		return addSubSystem(...)
	end
	harness.calls = calls
	harness.env.PlaySound = function(kit)
		Mock.sounds[#Mock.sounds + 1] = kit
	end
	return harness
end

local function Count(list, value)
	local count = 0
	for _, item in ipairs(list) do
		if item == value then
			count = count + 1
		end
	end
	return count
end

local function GuidFor(ns, tier, salt, npcId)
	for index = 1, 1000000 do
		local guid = "Creature-0-1-0-1-" .. (npcId or 1001) .. "-" .. salt .. string.format("%010X", index)
		if ns.Model.SpawnTier(guid) == tier then
			return guid
		end
	end
	error("no GUID rolls " .. tier)
end

-- Every sound this view plays is either the first-kill line's page turn or a toast's achievement chime.
local function OnlyJournalSounds(label)
	for _, sound in ipairs(Mock.sounds) do
		equal(sound == PAGE_TURN or sound == ACHIEVEMENT, true, label .. " (heard " .. tostring(sound) .. ")")
	end
end

-- A first kill: one yellow line where an explored area is announced, the page-turn sound, a New tag and the pulse.
local h = Start()
local ns = h.ns
local bronzeGuid = GuidFor(ns, "bronze", "first")
h:Kill("Plainstrider", 1001, bronzeGuid)
equal(#Mock.messages, 0, "nothing is shown from inside the kill handler")
h:RunTimers()
equal(#Mock.messages, 1, "a first kill shows one line")
equal(Mock.messages[1].text, "New creature recorded: Plainstrider", "the line names the creature")
equal(Mock.messages[1].r == 1 and Mock.messages[1].g == 1 and Mock.messages[1].b == 0, true, "the line is yellow")
equal(Count(Mock.sounds, PAGE_TURN), 1, "the page turns once")
equal(#Mock.alerts, 0, "a common first kill has no toast")
equal(#h.calls, 0, "a session without a milestone registers no toast subsystem")
equal(ns.GetCharacterState(false).unseen[1001], true, "the species is tagged New")
local glow = ns.Discovery.pulseGlow
equal(glow ~= nil and glow:IsShown(), true, "the minimap button's glow shows")
equal(ns.Discovery.pulse:IsPlaying(), true, "the minimap button pulses")
equal(ns.Discovery.pulse.looping, "REPEAT", "the pulse repeats until the journal opens")

h:Kill("Plainstrider", 1001, bronzeGuid)
h:RunTimers()
equal(#Mock.messages, 1, "a second kill of a known creature shows nothing")

-- The New tag survives a reload, and the journal showing the species clears it; opening the journal stops the pulse.
local migrated = ns.Migrate({
	version = ns.SCHEMA,
	chars = { x = { species = { [1001] = { count = 1 } }, unseen = { [1001] = true, [9] = true } } },
})
equal(migrated.chars.x.unseen[1001], true, "the New tag is saved")
equal(migrated.chars.x.unseen[9], nil, "a tag for a species with no record is dropped")
ns.Window.Show()
equal(glow:IsShown(), false, "opening the journal hides the glow")
equal(ns.Discovery.pulse:IsPlaying(), false, "opening the journal stops the pulse")
ns.Window.SelectSpecies(1001)
equal(ns.GetCharacterState(false).unseen[1001], nil, "showing the species clears its New tag")
for _, row in ipairs(ns.List.rows) do
	if row.species and row.species.id == 1001 then
		equal(row.New:IsShown(), false, "the row's tag goes at once")
	end
end

-- The list tags an unseen species with the mount journal's NEW, with no glow behind it.
ns.GetCharacterState(false).unseen = { [1001] = true }
ns.Window.Refresh()
local tagged
for _, row in ipairs(ns.List.rows) do
	if row.species and row.species.id == 1001 then
		tagged = row
	end
end
equal(tagged.New:GetText(), "NEW", "the tag reads NEW")
equal(rawget(tagged, "NewGlow"), nil, "the tag carries no glow")

-- A burst of first kills is one line, naming two and counting the rest, with one sound.
h = Start()
ns = h.ns
h:Kill("Plainstrider", 1001, GuidFor(ns, "bronze", "burst1"))
h:Kill("Savannah Prowler", 1003, GuidFor(ns, "bronze", "burst2", 1003))
h:RunTimers()
equal(#Mock.messages, 1, "a burst is one line")
equal(Mock.messages[1].text, "New creatures recorded: Plainstrider, Savannah Prowler", "the burst names both")
equal(Count(Mock.sounds, PAGE_TURN), 1, "a burst turns the page once")

-- A silver's first kill completes the zone: a toast for each, the silver first, and no line for it.
h:Kill("Dishu", 1019, GuidFor(ns, "silver", "dishu", 1019))
h:RunTimers()
equal(#Mock.messages, 1, "a first kill told by a toast has no line")
equal(#Mock.alerts, 2, "the silver and the zone each get a toast")
local silver, zone = Mock.alerts[1], Mock.alerts[2]
equal(h.calls[1], "load", "the achievement UI loads before the toast subsystem is registered")
equal(h.calls[2], "system", "the toast subsystem is registered after it")
equal(silver.template, "AchievementAlertFrameTemplate", "the toast is the client's achievement toast")
equal(silver.Unlocked:GetText(), "Silver found", "silver heading")
equal(silver.Name:GetText(), "Dishu", "silver toast names the creature")
equal(silver.id, nil, "the toast carries no achievement")
equal(silver.Shield:IsShown(), false, "the points shield is hidden")
equal(silver.Background.atlas, "ui-achievement-alert-background", "silver uses the standard toast art")
equal(silver.glow:IsShown(), false, "the toast has no glow")
equal(silver.shine:IsShown(), false, "the toast has no shine")
equal(silver.Icon.Texture._texture, ns.Art.SpeciesIcon("Dishu", 1019), "the toast shows the journal's icon")
equal(zone.Unlocked:GetText(), "Zone complete", "zone heading")
equal(zone.Name:GetText(), "The Barrens: every creature recorded", "zone toast names the zone")
equal(Count(Mock.sounds, ACHIEVEMENT), 2, "the silver and zone toasts each play the achievement chime once")
OnlyJournalSounds("the silver and zone toasts play no loot sound")

-- A left click opens the journal on the creature; a right click only dismisses.
silver:GetScript("OnClick")(silver, "RightButton")
equal(ns.Window.IsShown(), false, "a right click opens nothing")
equal(silver:IsShown(), false, "a right click dismisses the toast")
zone:GetScript("OnClick")(zone, "LeftButton")
equal(ns.Window.IsShown(), true, "a left click on the zone toast opens the journal")
ns.Window.Hide()
for index = 1, 8 do
	h:Kill("Plainstrider", 1001, GuidFor(ns, "bronze", "master" .. index))
end
h:RunTimers()
equal(#Mock.alerts, 2, "no toast before mastery")
local beforeMastery = Count(Mock.sounds, ACHIEVEMENT)
h:Kill("Plainstrider", 1001, GuidFor(ns, "bronze", "master9"))
h:RunTimers()
local mastered = Mock.alerts[3]
equal(mastered and mastered.Unlocked:GetText(), "Mastered", "the tenth specimen is a mastery toast")
equal(mastered.Name:GetText(), "Plainstrider", "mastery names the creature")
equal(mastered, silver, "the dismissed toast's frame is reused")
mastered:GetScript("OnClick")(mastered, "LeftButton")
equal(ns.Window.IsShown(), true, "a left click opens the journal")
equal(ns.Window.selected, 1001, "the journal opens on that creature")
equal(ns.Window.tab, "creatures", "on the creatures tab")
equal(ns.Detail.name:GetText(), "Plainstrider", "showing its entry")
h:Kill("Plainstrider", 1001)
h:RunTimers()
equal(#Mock.alerts, 3, "mastery is told once")
equal(Count(h.calls, "load"), 1, "the achievement UI loads only once")
equal(Count(Mock.sounds, ACHIEVEMENT) - beforeMastery, 1, "the mastery toast plays the achievement chime once")

-- A shiny is the biggest: the guild variant's larger art, the achievement chime; the next toast gets the standard art.
h = Start()
ns = h.ns
h:Kill("Plainstrider", 1001, GuidFor(ns, "shiny", "shiny"))
h:RunTimers()
local shiny = Mock.alerts[1]
equal(shiny.Unlocked:GetText(), "Shiny found", "shiny heading")
equal(shiny.Name:GetText(), "Shiny Plainstrider!", "shiny names the creature")
equal(shiny.Background.atlas, "ui-achievement-guild-background", "a shiny takes the larger guild art")
equal(shiny.glow:IsShown(), false, "the shiny toast has no glow")
equal(shiny.shine:IsShown(), false, "the shiny toast has no shine")
equal(shiny.GuildBanner:IsShown(), false, "without a guild banner")
equal(Count(Mock.sounds, ACHIEVEMENT), 1, "the shiny toast plays the achievement chime once")
OnlyJournalSounds("the shiny toast plays no loot sound")
equal(#Mock.messages, 0, "a shiny first kill has no line")

-- A pull of shinies shows at most BURST_TOASTS toasts, biggest first, through the two-on-screen queue.
h:Kill("Savannah Prowler", 1003, GuidFor(ns, "shiny", "pull1", 1003))
h:Kill("Dishu", 1019, GuidFor(ns, "shiny", "pull2", 1019))
h:Kill("Savannah Prowler", 1003, GuidFor(ns, "shiny", "pull3", 1003))
h:Kill("Dishu", 1019, GuidFor(ns, "shiny", "pull4", 1019))
h:RunTimers()
equal(#Mock.alerts, 2, "two toasts show at once")
equal(Mock.alerts[2].Background.atlas, "ui-achievement-guild-background", "the shinies come first")
for index = 1, #Mock.alerts do
	equal(Mock.alerts[index].Unlocked:GetText(), "Shiny found", "the cap keeps the biggest moments")
end
for _ = 1, 4 do
	Mock.alerts[#Mock.alerts]:Hide()
end
equal(#Mock.alerts, 1 + ns.Discovery.BURST_TOASTS, "a burst is capped")

-- With the line turned off a first kill is quiet but still tagged; with toasts off a tier falls back to the line.
h = Start({ discoveryText = false, milestoneToasts = false })
ns = h.ns
h:Kill("Plainstrider", 1001, GuidFor(ns, "bronze", "quiet"))
h:RunTimers()
equal(#Mock.messages, 0, "the line can be turned off")
equal(ns.GetCharacterState(false).unseen[1001], true, "the New tag stays")
ns.db.options.discoveryText = true
h:Kill("Dishu", 1019, GuidFor(ns, "silver", "quiet", 1019))
h:RunTimers()
equal(#Mock.alerts, 0, "toasts can be turned off")
equal(Mock.messages[1] and Mock.messages[1].text, "New creature recorded: Dishu", "a tier falls back to the line")

-- Both settings are checkboxes on the options page, on by default.
h = Start()
ns = h.ns
equal(ns.db.options.discoveryText, true, "the line is on by default")
equal(ns.db.options.milestoneToasts, true, "toasts are on by default")
local function Check(tooltip)
	for _, frame in ipairs(Mock.frames) do
		if frame.template == "InterfaceOptionsCheckButtonTemplate" and rawget(frame, "tooltipText") == tooltip then
			return frame
		end
	end
end
local line = Check(ns.L["A first kill shows one line at the top of the screen, where an explored area is announced."])
local toasts = Check(
	ns.L["Silver, gold, shiny, mastery and zone milestones show an achievement toast. Click it to open the journal."]
)
equal(line ~= nil and toasts ~= nil, true, "both checkboxes are on the page")
equal(line:GetChecked(), true, "the line's box starts ticked")
toasts:SetChecked(false)
toasts:GetScript("OnClick")(toasts)
equal(ns.db.options.milestoneToasts, false, "unticking turns the toasts off")

print("discovery_spec: " .. checks .. " checks passed")
