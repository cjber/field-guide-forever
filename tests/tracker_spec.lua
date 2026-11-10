-- The Track Species button puts the selected species in the shared Forever tracker column and takes it out again
-- (issue #149). The column is ForeverCore's: this spec presses the journal's own button
-- and reads the section it hands over, the way a player reads it on screen.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")

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
}

local harness = Mock.Harness()
local ns = harness.ns
harness.env.LibQuestieDB = {
	RequireContract = function()
		return true
	end,
	Npc = {
		GetAllIds = function()
			return { 1001, 1003 }
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

harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")
harness:Fire("PLAYER_ENTERING_WORLD")
harness:Fire("VARIABLES_LOADED")
harness:RunTimers()

-- At load the journal hands its section to the shared column, with nothing to draw until a species is tracked.
local section = assert(Mock.trackerSections[1], "the journal adds a section to the shared tracker column")
assert(section.headerText == "Field Guide", "the section names the addon, as Legacy's names its challenges")
assert(harness.env.ForeverCore.TrackerHost.IsAttached(section), "the shared column owns the section")
assert(section:GetContentsHeight() == 0, "a journal that tracks nothing has no section to draw")

local Window = ns.Window
local function Click()
	Window.trackButton:GetScript("OnClick")()
	harness:RunTimers()
end
local function Text(block, index)
	local line = block.objectives[index]
	return line and line.text
end

Window.Show()
-- This spec tracks undiscovered species too; the journal itself now opens on Discovered.
Window.SetFilter("all")
Window.SelectSpecies(1001)
assert(Window.trackButton.Label:GetText() == "Track Species", "the button offers to track the selected species")
Click()

-- Clicking track opens the section: the species, its zone and its progress.
assert(ns.GetCharacterState(false).tracked == 1001, "the click saves the tracked species")
assert(Window.trackButton.Label:GetText() == "Tracking", "the button says it is tracking")
local block = assert(section.blocks[1001], "the tracked species is the section's block")
assert(block.headerText == "Plainstrider", "the species name is the block header")
assert(Text(block, 1) == "The Barrens", "the species' zone is the first line")
assert(Text(block, 2) == "0 / 10 sightings", "its progress toward mastery follows")
assert(section:GetContentsHeight() > 0, "the section has a height to draw")
local column = assert(Mock.named.ForeverTrackerCompanion, "the shared column was built")
assert(column:IsShown(), "the column shows while a species is tracked")

-- A kill reaches the section: the column refreshes on progress, without the journal being reopened.
Mock.Kill("Plainstrider", 1001)
harness:RunTimers()
block = assert(section.blocks[1001], "the section survives a progress update")
assert(Text(block, 2) == "1 / 10 sightings", "the sighting count follows the kill")
assert(Text(block, 3) == "1 kill", "the kill is listed on its own line")

-- A second species replaces the first, as the journal tracks one creature at a time.
Window.SelectSpecies(1003)
Click()
assert(ns.GetCharacterState(false).tracked == 1003, "tracking another species moves the switch")
assert(section.blocks[1003] and not section.blocks[1001], "the section shows only the species being tracked")
assert(section.headerText == "Field Guide", "the section keeps its own header")

-- Clicking the button again stops tracking: the section empties and the column hides itself.
Click()
assert(ns.GetCharacterState(false).tracked == nil, "the click clears the tracked species")
assert(Window.trackButton.Label:GetText() == "Track Species", "the button offers to track again")
assert(section:GetContentsHeight() == 0, "nothing tracked means nothing to draw")
assert(not section.blocks[1003], "the untracked species' block is released")
assert(not column:IsShown(), "the column hides when it has no section")

print("tracker: ok")

-- Field Guide kept the column's scale, lock and position before ForeverCore did. The first section offers that old
-- table once, so the player keeps the layout they chose, then the key goes.
local migrated = Mock.Harness()
migrated.env.FieldGuideForeverDB = { trackerHost = { attached = false, locked = true, scale = 1.5 } }
migrated:Fire("ADDON_LOADED", "FieldGuideForever")
migrated:Fire("PLAYER_LOGIN")
local settings = migrated.env.ForeverCore.TrackerHost.GetSettings()
assert(
	settings.scale == 1.5 and settings.locked == true and settings.attached == false,
	"the old tracker settings carry over"
)
assert(migrated.env.FieldGuideForeverDB.trackerHost == nil, "the old tracker table is offered once")
print("tracker settings: ok")
