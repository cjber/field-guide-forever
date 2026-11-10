-- Field Guide Forever's part of the shared error journal and report: the journal lives in FieldGuideForeverDB after
-- the saved variables load, and /fg report is routed to the shared report window before the addon's own commands.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local env, ns = harness.env, harness.ns

harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:RunTimers()

local db = env.FieldGuideForeverDB
assert(db, "the saved variables exist after the addon loads")
assert(type(db.errors) == "table", "the shared error journal has its saved table")
assert(type(db.log) == "table" and type(db.log.lines) == "table", "the shared debug log has its saved ring")
assert(db.log.pinned == false, "a fresh log ring is unpinned")

-- An error recorded through either shared entry point is kept in the saved journal, so a reload keeps it.
ns.core.RecordError("test", "journal error", "stack")
local found = false
for _, entry in ipairs(db.errors) do
	if entry.message == "journal error" then
		found = true
	end
end
assert(found, "RecordError writes to FieldGuideForeverDB.errors")

local ok = ns.core.SafeCall("test", function()
	error("safe call error")
end)
assert(not ok, "SafeCall reports the failure")
found = false
for _, entry in ipairs(db.errors) do
	if entry.message and entry.message:find("safe call error", 1, true) then
		found = true
	end
end
assert(found, "a failure SafeCall catches reaches the saved journal")

-- /fg report goes to the shared report instead of opening the field guide, and the report carries this addon's
-- own lines. The window itself is not built here.
env.C_AddOns = {
	GetAddOnMetadata = function()
		return "0.0.0"
	end,
	GetNumAddOns = function()
		return 0
	end,
}
env.UnitRace = function()
	return "Human"
end
env.UnitFactionGroup = function()
	return "Alliance"
end
env.C_Map.GetBestMapForUnit = function()
	return nil
end
local shown
ns.core.Report.Show = function(text)
	shown = text
end
env.SlashCmdList.FIELDGUIDEFOREVER("report")
assert(shown, "/fg report is handled by the shared report command")
assert(shown:find("creatures recorded for this character", 1, true), "the report carries this addon's own lines")
assert(shown:find("QuestieDB catalogue:", 1, true), "the report says whether the catalogue loaded")

print("error_journal: ok")
