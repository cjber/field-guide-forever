-- One client icon for every in-game identity surface: the TOC declares it once, Core reads it once, and the minimap
-- button and the journal's side tab and portrait all draw that same value.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local env, ns = harness.env, harness.ns

harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")

local declared = env.C_AddOns.GetAddOnMetadata("FieldGuideForever", "X-Forever-Icon")
assert(
	declared == "Interface\\Icons\\INV_Misc_Book_09",
	"the TOC declares the addon's client icon: " .. tostring(declared)
)
assert(ns.icon == declared, "Core reads the TOC icon once onto the namespace: " .. tostring(ns.icon))

local button = env.FieldGuideForeverMinimapButton
assert(button and button.minimapButtonSpec.icon == declared, "the minimap button wears the identity icon")

ns.Window.Show()
local frame = env.FieldGuideForeverFrame
assert(frame, "the journal window was not built")
assert(frame.PortraitContainer.portrait._texture == declared, "the journal portrait wears the identity icon")
assert(ns.Window.tabButtons[1].Icon._texture == declared, "the creatures side tab wears the identity icon")

print("identity icon: ok")
