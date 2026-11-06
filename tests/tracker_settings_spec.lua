-- The shared tracker column's attach, lock, scale and drag position live in the saved variables, in the same root
-- trackerHost table Legacy Forever uses. The host reads them before the saved variables reach ns.db, so the global
-- table is the fallback, and an old or malformed record gains the keys it is missing.
local Mock = dofile("tests/wow_mock.lua")

---@param saved table
---@return table
local function Load(saved)
	local harness = Mock.Harness()
	harness.env.FieldGuideForeverDB = saved
	harness:Fire("ADDON_LOADED", "FieldGuideForever")
	return harness
end

-- The UI host can ask for settings while the files load, before the saved variables are migrated.
local early = Mock.Harness()
local earlySettings = early.ns.TrackerHostSettings()
assert(type(earlySettings) == "table", "the tracker settings exist before the saved variables load")
assert(earlySettings.attached == true, "a fresh tracker starts attached")
assert(earlySettings.locked == false, "a fresh tracker starts unlocked")

-- A saved record keeps the switches, scale and detached position, and an old one gains the Lock switch off.
local saved = {
	version = early.ns.SCHEMA,
	chars = {},
	options = {},
	trackerHost = { attached = false, scale = 1.5, x = 120, y = -240 },
}
local harness = Load(saved)
local ns = harness.ns
local host = saved.trackerHost
local settings = ns.TrackerHostSettings()
assert(settings == host, "the host reads the saved trackerHost table itself")
assert(settings.attached == false, "the saved attach switch survives")
assert(settings.locked == false, "an old record gains Lock off")
assert(settings.scale == 1.5, "the saved scale survives")
assert(settings.x == 120 and settings.y == -240, "the saved detached position survives")

-- Every switch is written back through the host, so the saved variable is the one source of truth.
local api = ns.TrackerHost
assert(type(api) == "table", "the shared host is loaded")
api.SetScale(1.25)
assert(host.scale == 1.25, "a scale change is saved")
api.SetLocked(true)
assert(host.locked == true, "the Lock switch is saved")
api.SetAttached(true)
assert(host.attached == true, "re-attaching is saved")
api.SetAttached(false)
assert(host.attached == false, "detaching is saved")
api.SavePosition(48, -64)
assert(host.x == 48 and host.y == -64, "a detached drag is saved")
assert(api.GetSettings() == host, "the host and the saved table are the same record")

-- A malformed record is replaced rather than trusted.
local broken = {
	version = early.ns.SCHEMA,
	chars = {},
	options = {},
	trackerHost = "not a table",
}
local repaired = Load(broken).ns.TrackerHostSettings()
assert(type(repaired) == "table", "a malformed trackerHost becomes a table")
assert(repaired.attached == true and repaired.locked == false, "a malformed trackerHost takes the defaults")

print("tracker settings: ok")
