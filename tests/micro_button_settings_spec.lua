local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
harness.Fire(harness, "ADDON_LOADED", "FieldGuideForever")
harness.Fire(harness, "PLAYER_LOGIN")

local ns, button = harness.ns, harness.env.FieldGuideForeverMicroButton
assert(ns.db.options.microButton == true)
assert(button and button:IsShown())

local checkbox
for index = #Mock.frames, 1, -1 do
	local frame = Mock.frames[index]
	if frame._type == "CheckButton" and frame._scripts.OnClick then
		checkbox = frame
		break
	end
end
assert(checkbox, "micro menu checkbox was not registered")
checkbox:SetChecked(false)
checkbox._scripts.OnClick(checkbox)
assert(ns.db.options.microButton == false and not button:IsShown())
checkbox:SetChecked(true)
checkbox._scripts.OnClick(checkbox)
assert(ns.db.options.microButton == true and button:IsShown())
print("micro button settings: ok")
