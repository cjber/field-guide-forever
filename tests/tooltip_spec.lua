-- UI/Tooltip.lua: a creature's tooltip keeps a minimum width, so a short name does not squeeze the facts under it
-- onto extra lines, and gives the shared GameTooltip its own width back when it hides.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local env, ns = harness.env, harness.ns
harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")

local minimum, lines, shown = 0, {}, false
env.GameTooltip = {
	SetOwner = function() end,
	ClearLines = function()
		lines = {}
	end,
	SetMinimumWidth = function(_, width)
		minimum = width
	end,
	AddLine = function(_, text)
		lines[#lines + 1] = text
	end,
	Show = function()
		shown = true
	end,
	Hide = function()
		shown = false
	end,
}

local species = { id = 1, name = "Rat", family = "Critter", zone = "Elwynn Forest", minLevel = 1, maxLevel = 1 }
ns.Tooltip.Show({}, { species = species, state = { count = 0 } })
assert(shown and lines[1] == "Rat", tostring(lines[1]))
assert(minimum >= 200, "a short name sizes the tooltip: minimum " .. minimum)
ns.Tooltip.Hide()
assert(not shown and minimum == 0, "the shared tooltip keeps the creature minimum: " .. minimum)
print("tooltip_spec: 4 checks passed")
