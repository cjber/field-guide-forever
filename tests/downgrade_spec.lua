-- A save written by a newer Field Guide survives a session of this one, so going back to that version finds it.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns

local saved = {
	version = ns.SCHEMA + 1,
	chars = { ["Barry-Realm"] = { species = { [124] = { count = 5, kills = 5 } }, future = true } },
	options = { showUndiscovered = false },
}
harness.env.FieldGuideForeverDB = saved
harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:RunTimers()
assert(ns.ready, "the addon still runs over a newer save")
assert(harness.env.FieldGuideForeverDB == saved, "the newer save stays the saved variable")
assert(saved.version == ns.SCHEMA + 1, "the newer save keeps its version")
assert(saved.chars["Barry-Realm"].species[124].count == 5, "the newer save keeps its journal")
assert(saved.chars["Barry-Realm"].future == true, "fields this version does not know are kept")
assert(saved.options.showUndiscovered == false, "the newer save keeps its options")
assert(ns.db ~= saved and ns.db.version == ns.SCHEMA, "this session records into a table that is not saved")

local current = ns.Migrate({ version = ns.SCHEMA, chars = {} })
local db, newer = ns.Migrate(current)
assert(db == current and not newer, "a current save is migrated in place")
print("downgrade specs passed")
