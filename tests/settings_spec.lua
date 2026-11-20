-- The options page: two headings (Journal, Announcements), the rows under them in order,.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")

local harness = Mock.Harness()
harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")
local panel = harness.ns.Settings.panel
assert(panel, "the settings page was not registered")

local headings = 0
for _, row in ipairs(panel.settingsRows) do
	if row.header then
		headings = headings + 1
	end
end
assert(headings == 2, "expected two headings, got " .. headings)
assert(panel.settingsRows[1].header, "the page opens on a heading")
assert(harness.ns.L["Journal"] == "Journal" and harness.ns.L["Announcements"] == "Announcements", "heading phrases")
