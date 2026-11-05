-- UI/Tooltip.lua: Field Guide's creature and micro-menu tooltips share one minimum width, so a short title does not
-- squeeze the facts under it onto extra lines, and the shared GameTooltip gets its own width back when they hide.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local env, ns = harness.env, harness.ns
-- The shared button stores GameTooltip_Hide when it creates its OnLeave script, so count it before login.
local sharedHides = 0
env.GameTooltip_Hide = function()
	sharedHides = sharedHides + 1
end
harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")

local minimum, lines, shown, calls = 0, {}, false, {}
env.GameTooltip = {
	SetOwner = function()
		calls[#calls + 1] = "SetOwner"
	end,
	ClearLines = function()
		calls[#calls + 1] = "ClearLines"
		lines = {}
		minimum = 0
	end,
	SetText = function(_, text)
		-- The client measures a new title from scratch, forgetting any minimum width set before it.
		calls[#calls + 1] = "SetText"
		lines = { text }
		minimum = 0
	end,
	SetMinimumWidth = function(_, width)
		calls[#calls + 1] = "SetMinimumWidth"
		minimum = width
	end,
	AddLine = function(_, text)
		calls[#calls + 1] = "AddLine"
		lines[#lines + 1] = text
	end,
	Show = function()
		calls[#calls + 1] = "Show"
		shown = true
	end,
	Hide = function()
		calls[#calls + 1] = "Hide"
		shown = false
	end,
}

local species = { id = 1, name = "Rat", family = "Critter", zone = "Elwynn Forest", minLevel = 1, maxLevel = 1 }
ns.Tooltip.Show({}, { species = species, state = { count = 0 } })
assert(shown and lines[1] == "Rat", tostring(lines[1]))
assert(minimum >= 200, "a short name sizes the tooltip: minimum " .. minimum)
ns.Tooltip.Hide()
assert(not shown and minimum == 0, "the shared tooltip keeps the creature minimum: " .. minimum)

-- The micro-menu button sets its title with SetText, which forgets a width set earlier: Field Guide's tooltip must
-- set the minimum after the title, and its hook must leave the shared handler's own tooltip in place before that.
local button = env.FieldGuideForeverMicroButton
assert(button, "the micro-menu button was created")
lines, shown, minimum, calls = {}, false, 0, {}
button._scripts.OnEnter(button)
assert(shown and lines[1] == "Field Guide", tostring(lines[1]))
assert(minimum >= 200, "a short micro-menu title sizes the tooltip: minimum " .. minimum)
local firstMinimum
for index, name in ipairs(calls) do
	if name == "SetMinimumWidth" then
		firstMinimum = index
		break
	end
end
assert(firstMinimum, "the micro-menu tooltip asks for a minimum width")
local shared = false
for index = 1, (firstMinimum or 1) - 1 do
	if calls[index] == "Show" then
		shared = true
	end
end
assert(shared, "the shared OnEnter still shows its own tooltip before Field Guide redraws it")
button._scripts.OnLeave(button)
assert(not shown and minimum == 0, "the shared tooltip keeps the micro-menu minimum: " .. minimum)
assert(sharedHides == 1, "the shared OnLeave still runs: " .. sharedHides)
print("tooltip_spec: 10 checks passed")
