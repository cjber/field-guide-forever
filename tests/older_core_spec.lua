-- The loader adopts an installed standalone ForeverCore as it is, even when it is older than the pinned release, so
-- Field Guide loads on any runtime that serves its consumer API. ForeverCore 1.15.3 has no
-- SettingsPage.AddTrackerAttach (added in 1.15.4): the options page goes without the Attach tick box, and every row
-- after it still builds.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")

local function Panel(opts, wrap)
	local harness = Mock.Harness(opts)
	if wrap then
		wrap(harness.env.ForeverCore.SettingsPage)
	end
	harness:Fire("ADDON_LOADED", "FieldGuideForever")
	harness:Fire("PLAYER_LOGIN")
	local panel = harness.ns.Settings.panel
	assert(panel, "the settings page was not registered")
	return panel
end

-- This fake frame answers every unknown field, so core's own tick box draws nothing here; the call is what is checked.
local asked = 0
local current = Panel(nil, function(page)
	local add = page.AddTrackerAttach
	page.AddTrackerAttach = function(...)
		asked = asked + 1
		return add(...)
	end
end)
assert(asked == 1, "a current core is asked for the Attach tick box once")

local older = Panel({ coreWithout = { "SettingsPage.AddTrackerAttach" } })
assert(
	#older.settingsRows == #current.settingsRows,
	("every other row still builds: %d rows, expected %d"):format(#older.settingsRows, #current.settingsRows)
)

print("older_core_spec: ok")
