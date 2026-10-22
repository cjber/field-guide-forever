local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness({
	files = {
		"Locales/enUS.lua",
		"Data/Client.lua",
		"Data/CreatureIcons.lua",
		"Core/Model.lua",
		"UI/Art.lua",
		"UI/Detail.lua",
	},
})
local ns = harness.ns
local Detail = ns.Detail

-- The detail pane reads the character's saved record through Core; this spec only cares about the viewport.
ns.GetCharacterState = function()
	return nil
end

Detail.Create(harness.env.UIParent)

local portrait = Detail.portrait
assert(portrait, "the detail pane builds a portrait viewport")
assert(portrait.model, "the viewport is a real client model frame, not a stand-in texture")

local species = {
	id = 334,
	name = "Gath'Ilzogg",
	family = "Humanoid",
	minLevel = 30,
	maxLevel = 30,
	lore = "A Blackrock orc who holds the keep above Stonewatch.",
}
local zone = { id = 44, name = "Redridge Mountains" }

Detail.Show(species, { count = 2, kills = 4, rare = 0, shiny = 0 }, zone)
assert(portrait.model:GetCreature() == species.id, "the entry shows the NPC's own model, requested by its catalogue id")
assert(portrait.model._shown, "the model is shown when a creature is selected")
assert(not portrait.fallback._shown, "the icon fallback is hidden while the real model renders")

-- The empty state has no NPC to render, so it returns to the icon instead of leaving the last model up.
Detail.Show(nil, nil, nil)
assert(not portrait.model._shown, "the model is hidden when no creature is selected")
assert(portrait.fallback._shown, "the fallback icon covers the empty state")

print("model_portrait: ok")
