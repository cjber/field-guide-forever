-- UI/Window.lua as an addon-owned window: it opens and closes itself rather than through the panel manager, is closed
-- by Escape, and opens in combat without ever writing the gamepad frame bookkeeping.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local env, Window = harness.env, harness.ns.Window

-- Not a panel-manager entry: any addon ShowUIPanel or HideUIPanel taints the gamepad bookkeeping (#253).
assert(env.UIPanelWindows.FieldGuideForeverFrame == nil, "not registered as a UI panel")
assert(env.FieldGuideForeverFrame == nil, "the frame is built on first open, not at load")

harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")
assert(harness.ns.db.window == nil, "no saved position")

-- Open and close stay outside the panel manager, where the gamepad bookkeeping is never touched.
Window.Toggle()
local frame = env.FieldGuideForeverFrame
assert(frame and frame:IsShown() and Window.IsShown())
assert(#Window.tabButtons == 2, "the side rail has two tabs")
assert(Window.tabButtons[1].key == "creatures" and Window.tabButtons[2].key == "instances")
-- Each tab's tooltip names it in plain case, with a line saying what it holds.
local lines = {}
local tooltip = {
	SetText = function(_, text)
		lines[#lines + 1] = text
	end,
	AddLine = function(_, text)
		lines[#lines + 1] = text
	end,
}
assert(Window.tabButtons[2]:GetTooltipTextSetupFunction()(tooltip), "the tab fills its own tooltip")
assert(lines[1] == "Instances" and lines[2] == "Boss encounters recorded on this character", table.concat(lines, "|"))
assert(#Mock.panelCalls == 0 and Mock.panelSlot == nil, "opening asks nothing of the panel manager")
local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
assert(point == "TOPLEFT" and relativeTo == env.UIParent and relativePoint == "TOPLEFT" and x == 16 and y == -116)
assert(
	frame._scripts.OnDragStart == nil and frame._scripts.OnDragStop == nil,
	"a panel is placed by the game, not dragged"
)
Window.Show()
assert(#Mock.panelCalls == 0, "showing an open window again asks nothing of the manager")
Window.Toggle()
assert(not frame:IsShown() and #Mock.panelCalls == 0, "closing asks nothing of the panel manager")

-- Escape closes it.
Window.Show()
assert(frame:IsShown())
assert(env.CloseAllWindows() and not frame:IsShown())

-- Combat changes nothing: the window already opens and closes on its own, never blocked.
env.InCombatLockdown = function()
	return true
end
Window.Toggle()
assert(frame:IsShown() and #Mock.panelCalls == 0 and not Mock.blocked)
assert(env.CloseAllWindows() and not frame:IsShown(), "Escape closes it in combat too")
Window.Show()
Window.Hide()
assert(not frame:IsShown() and not Mock.blocked)
print("window: ok")
