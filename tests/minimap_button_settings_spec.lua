-- The minimap button Core/Settings.lua creates and the setting that hides it: the button carries Field Guide's own
-- icon, title, binding, description and click action, is shown by default, and an old hidden micro menu setting moves
-- across once.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")

local function Start(options)
	local harness = Mock.Harness()
	if options then
		harness.env.FieldGuideForeverDB = { options = options }
	end
	harness:Fire("ADDON_LOADED", "FieldGuideForever")
	harness:Fire("PLAYER_LOGIN")
	return harness
end

local harness = Start()
local ns = harness.ns
local button = harness.env.FieldGuideForeverMinimapButton
assert(button, "the minimap button was not created")
assert(button:GetParent() == harness.env.Minimap, "the button is parented to the Minimap")
assert(button:IsShown(), "the button is shown by default")
assert(ns.db.options.minimapButtonHidden == false, "hidden starts false")
assert(ns.db.options.microButton == nil, "the old micro menu setting is gone")

local spec = button.minimapButtonSpec
assert(spec, "the creation spec is kept")
assert(spec.icon == "Interface\\Icons\\ability_hunter_pet_wolf", tostring(spec.icon))
assert(spec.title == "Field Guide", tostring(spec.title))
assert(spec.binding == "Shift-F", tostring(spec.binding))
assert(spec.subtext == "Click to browse the field compendium", tostring(spec.subtext))
assert(spec.settings == ns.db.options, "the saved options are the button's settings")
assert(spec.onClick == ns.OpenGuide, "the click action opens the journal")
assert(ns.minimapButton == button, "the button is published on the namespace")

local checkbox
for index = #Mock.frames, 1, -1 do
	local frame = Mock.frames[index]
	if
		frame._type == "CheckButton"
		and frame._scripts.OnClick
		and frame.tooltipText == ns.L["Adds a Field Guide button to the minimap."]
	then
		checkbox = frame
		break
	end
end
assert(checkbox, "the minimap button checkbox was not registered")
assert(checkbox:GetChecked(), "the checkbox starts ticked")
checkbox:SetChecked(false)
checkbox._scripts.OnClick(checkbox)
assert(ns.db.options.minimapButtonHidden == true and not button:IsShown(), "unticking hides the button")
checkbox:SetChecked(true)
checkbox._scripts.OnClick(checkbox)
assert(ns.db.options.minimapButtonHidden == false and button:IsShown(), "ticking shows the button")

-- A player who had hidden the micro menu button keeps its replacement hidden; the old key is removed.
local migrated = Start({ microButton = false })
assert(migrated.ns.db.options.minimapButtonHidden == true, "the old hidden setting moves across")
assert(migrated.ns.db.options.microButton == nil, "the old setting is removed")
assert(not migrated.env.FieldGuideForeverMinimapButton:IsShown(), "the migrated button is hidden")

local shown = Start({ microButton = true })
assert(shown.ns.db.options.minimapButtonHidden == false, "a shown micro button leaves the minimap button shown")
assert(shown.env.FieldGuideForeverMinimapButton:IsShown(), "the migrated button is shown")

print("minimap button settings: ok")
