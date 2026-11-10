-- UI/Window.lua under the gamepad interface: the window still opens and closes, but never through the panel manager.
-- Its pickers go through ForeverCore's own context menu, which draws in frames of its own and leaves the gamepad focus
-- alone (#253).
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local env, Window = harness.env, harness.ns.Window

harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")

local gamepad = true
env.InputUtil = {
	IsGamepadUIEnabled = function()
		return gamepad
	end,
}
local menus = 0
env.ForeverCore.ContextMenu = function()
	menus = menus + 1
end
env.MenuUtil = {
	CreateContextMenu = function()
		error("the addon opened a Blizzard menu")
	end,
}

-- Under the gamepad interface the window opens outside the panel manager, placed where a left panel sits.
Window.Show()
local frame = env.FieldGuideForeverFrame
assert(frame and frame:IsShown() and Window.IsShown())
assert(#Mock.panelCalls == 0, "the gamepad interface opens the window without ShowUIPanel")
local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
assert(point == "TOPLEFT" and relativeTo == env.UIParent and relativePoint == "TOPLEFT" and x == 16 and y == -116)

-- The zone and filter pickers use ForeverCore's menu, so they leave the gamepad focus untouched.
Mock.messages = {}
Window.ToggleZoneMenu()
Window.ToggleFilterMenu()
assert(menus == 2, "the gamepad interface opens the shared context menu twice")
assert(#Mock.messages == 0, "the pickers need no mouse and keyboard line")

-- Closing stays outside the manager too, and Escape still closes the window.
Window.Hide()
assert(not frame:IsShown() and #Mock.panelCalls == 0, "the gamepad interface closes the window without HideUIPanel")
Window.Show()
assert(env.CloseAllWindows() and not frame:IsShown(), "Escape closes the gamepad window")

-- With the gamepad interface off the window still opens and closes itself; the pickers use the same shared menu.
gamepad = false
Mock.messages = {}
menus = 0
Window.Show()
assert(Mock.panelCalls[1] == nil, "the window never asks the panel manager, gamepad on or off")
Window.ToggleZoneMenu()
Window.ToggleFilterMenu()
assert(menus == 2, "without the gamepad interface both pickers open the shared menu")
assert(#Mock.messages == 0, "the pickers open without a fallback line")
Window.Hide()
assert(not frame:IsShown() and Mock.panelCalls[1] == nil)
print("window gamepad: ok")
