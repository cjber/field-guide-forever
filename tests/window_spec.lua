-- UI/Window.lua as a native UI panel: registered with the panel manager at load, opened and closed through it, closed
-- by Escape, and still usable in combat, when the manager refuses addon calls.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local env, Window = harness.env, harness.ns.Window

-- Registered at load, before anything opens it, like the Adventure Guide.
local panel = env.UIPanelWindows.FieldGuideForeverFrame
assert(panel, "not registered as a UI panel")
assert(panel.area == "left" and panel.pushable == 0 and panel.whileDead == 1 and panel.width == 960)
assert(env.FieldGuideForeverFrame == nil, "the frame is built on first open, not at load")

harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")
assert(harness.ns.db.window == nil, "no saved position")

-- Open and close go through the panel manager.
Window.Toggle()
local frame = env.FieldGuideForeverFrame
assert(frame and frame:IsShown() and Window.IsShown())
assert(Mock.panelSlot == frame and Mock.panelCalls[1] == "show")
assert(
	frame._scripts.OnDragStart == nil and frame._scripts.OnDragStop == nil,
	"a panel is placed by the game, not dragged"
)
Window.Show()
assert(#Mock.panelCalls == 1, "showing an open panel again asks nothing of the manager")
Window.Toggle()
assert(not frame:IsShown() and Mock.panelSlot == nil and Mock.panelCalls[2] == "hide")

-- Escape closes it.
Window.Show()
assert(frame:IsShown())
assert(env.CloseAllWindows() and not frame:IsShown())

-- In combat the manager refuses addon calls, so the journal opens and closes on its own, never blocked.
env.InCombatLockdown = function()
	return true
end
Window.Toggle()
assert(frame:IsShown() and Mock.panelSlot == nil and not Mock.blocked)
local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
assert(point == "TOPLEFT" and relativeTo == env.UIParent and relativePoint == "TOPLEFT" and x == 16 and y == -116)
assert(env.CloseAllWindows() and not frame:IsShown(), "Escape closes it in combat too")
Window.Show()
Window.Hide()
assert(not frame:IsShown() and not Mock.blocked)
print("window: ok")
