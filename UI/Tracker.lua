---@type string, FGNamespace
local _, ns = ...
local L = ns.L

-- A tracked species gets a section in the shared Forever tracker column, the one Forever Core owns and every Forever
-- addon vendors in UI/Tracker*.lua: this file supplies only the section, as Legacy Forever supplies its challenges.
-- One species is tracked at a time, the one the journal's button shows, and that switch is saved as state.tracked
-- (Core/Migrate keeps it). The column draws the section under the game's own objectives and hides it while the
-- character tracks nothing.
---@class FGTracker
local Tracker = {}
ns.Tracker = Tracker

---@return integer?
local function Tracked()
	local state = ns.GetCharacterState(false)
	local id = state and tonumber(state.tracked)
	if id and id > 0 and id % 1 == 0 then
		return id
	end
end

---@param speciesId integer
---@return boolean
function Tracker.IsTracked(speciesId)
	return Tracked() == speciesId
end

---@type FGTrackerModule?
local module

-- Asks the column to lay the section out again. A kill, a sighting and the button all land here; writing a saved
-- switch is safe in combat, and the column itself waits for combat's end before it moves anything.
function Tracker.Refresh()
	if module then
		module:MarkDirty()
	end
end

-- The journal's button: track the species it shows, or stop tracking it. The saved switch is the whole state, so a
-- reload, a zone change and the next log in all keep the section as the player left it.
---@param speciesId integer
function Tracker.Toggle(speciesId)
	local state = ns.GetCharacterState(true)
	if not state then
		return
	end
	if state.tracked == speciesId then
		state.tracked = nil
	else
		state.tracked = speciesId
	end
	Tracker.Refresh()
end

-- The species' lines, in the order the detail pane reads them: where it lives, what this character has recorded of
-- it, and how often it has died here.
---@param species FGSpecies
---@return string[]
local function Lines(species)
	local entry = ns.Model.Specimen(ns.GetCharacterState(false), species.id)
	local lines = {}
	local zone = ns.SpeciesZone and ns.SpeciesZone[species.id]
	if zone then
		lines[#lines + 1] = L[zone.name]
	end
	lines[#lines + 1] = string.format(L["%d / %d sightings"], entry.count or 0, ns.Model.MASTERED_AT)
	local kills = entry.kills or 0
	if kills > 0 then
		lines[#lines + 1] = string.format(kills == 1 and L["%d kill"] or L["%d kills"], kills)
	end
	return lines
end

---@class FGTrackerSection : FGTrackerModule
local ModuleMixin = { headerText = L["Field Guide"] }

-- The species as the block header, then those lines, like a quest's own objectives. A species the catalogue has not
-- loaded yet, or an id from another build, draws nothing: the column then has no section to show and hides itself.
function ModuleMixin:LayoutContents()
	local speciesId = Tracked()
	local species = speciesId and ns.SpeciesById and ns.SpeciesById[speciesId] or nil
	if not species or ns.catalogueStatus ~= "ok" then
		return
	end
	local block = self:GetBlock(species.id)
	block:SetHeader(species.name)
	for index, text in ipairs(Lines(species)) do
		block:AddObjective(index, text)
	end
	self:LayoutBlock(block)
end

---@return boolean
local function Available()
	return ObjectiveTrackerFrame ~= nil and ObjectiveTrackerManager ~= nil
end

-- A column section is the game's own ObjectiveTrackerModuleTemplate. The host takes it over in Attach: it parents
-- the section into its column, orders it, and gives its header the column's right-click switches.
local function Attach()
	if not Available() or not ns.TrackerHost then
		return
	end
	local section =
		CreateFrame("Frame", "FieldGuideForeverObjectiveTracker", UIParent, "ObjectiveTrackerModuleTemplate")
	---@cast section FGTrackerModule
	Mixin(section, ModuleMixin)
	section:SetHeader(ModuleMixin.headerText)
	-- After the Forever sections that were here first, so the journal's species follows a player's challenges.
	section.uiOrder = 10
	module = section
	ns.TrackerHost.Attach(section)
	Tracker.Refresh()
end

Attach()
ns.OnProgress(Tracker.Refresh)
