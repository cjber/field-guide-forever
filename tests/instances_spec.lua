-- UI/Instances.lua: catalogue bosses and this character's encounter records grouped by instance, visited instances
-- first, a search over instance and boss names, and the open instance's card, bosses and totals.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local ns, env = harness.ns, harness.env
local View = ns.InstancesView

local function Boss(id, name, level)
	return { id = id, name = name, minLevel = level, maxLevel = level, family = "Humanoid", boss = true }
end
local catalogue = {
	{
		id = 36,
		name = "Deadmines",
		instanceType = 1,
		species = {
			Boss(644, "Rhahk'Zor", 19),
			Boss(645, "Cookie", 20),
			Boss(639, "Edwin VanCleef", 21),
			{ id = 4075, name = "Rat", minLevel = 1, maxLevel = 1, family = "Critter" },
		},
	},
	{ id = 43, name = "Wailing Caverns", instanceType = 1, species = { Boss(3654, "Mutanus the Devourer", 22) } },
	{ id = 409, name = "Molten Core", instanceType = 2, species = {} },
}
local records = {
	{ id = 1, name = "Rhahk'Zor", instance = "Deadmines", kills = 4, sightings = 4, firstKill = 0 },
	{ id = 2, name = "Edwin VanCleef", instance = "Deadmines", kills = 1, sightings = 2 },
	{ id = 3, name = "Mutanus the Devourer", instance = "Wailing Caverns", kills = 1, sightings = 1 },
	{ id = 4, name = "Ghost Boss", instance = "Somewhere Else", kills = 0, sightings = 1 },
}

local groups = View.Group(catalogue, records)
local names = {}
for index, group in ipairs(groups) do
	names[index] = group.name
end
assert(
	table.concat(names, ",") == "Deadmines,Somewhere Else,Wailing Caverns,Molten Core",
	"visited instances come first, then by name: " .. table.concat(names, ",")
)
assert(groups[1].done == 2 and #groups[1].rows == 3, "Deadmines has two of three bosses down")
assert(groups[2].rows[1].name == "Ghost Boss", "an unlisted record keeps its own instance")

View.Create(env.CreateFrame("Frame"))
View.Refresh(catalogue, records, "")
assert(View.rows[1].Name:GetText() == "Deadmines", "the first visited instance opens")
assert(View.rows[1].Sub:GetText() == "2 of 3 bosses", View.rows[1].Sub:GetText())
assert(View.rows[4].Sub:GetText() == "Not visited", "an instance with nothing recorded says so")
assert(View.rows[3].Mark:IsShown(), "a cleared instance carries the gold mark")
assert(not View.rows[1].Mark:IsShown(), "a part-cleared instance carries none")
assert(View.name:GetText() == "Deadmines" and View.Breadcrumb() == "Dungeons > Deadmines", View.Breadcrumb())
assert(View.sub:GetText() == "Dungeon · Level 19-21", "level 1 critters stay out of the range: " .. View.sub:GetText())
assert(View.progress:GetText() == "2 of 3 bosses recorded", View.progress:GetText())
assert(View.bossRows[2].Detail:GetText() == "Not defeated yet", "Cookie is not down")
assert(View.bossRows[3].Detail:GetText() == "1 kill", View.bossRows[3].Detail:GetText())
assert(View.cleared:GetText() == "1 of 3", "Wailing Caverns is the one cleared catalogue instance")
assert(View.kills:GetText() == "6 boss kills recorded", View.kills:GetText())

View.Refresh(catalogue, records, "mutanus")
assert(View.rows[1].Name:GetText() == "Wailing Caverns", "a boss name finds its instance")
assert(not View.rows[2]:IsShown(), "other instances leave the list")
assert(View.Breadcrumb() == "Dungeons > Wailing Caverns", "the search moves the open instance into view")

View.Refresh(catalogue, records, "no such place")
assert(View.listEmpty:IsShown() and View.empty:IsShown(), "an empty search says so on both sides")

View.Refresh(catalogue, records, "molten")
assert(View.Breadcrumb() == "Raids > Molten Core", "a raid is filed under raids")

-- The Barrens' map draws all twelve base tiles plus its overlays; a map without art leaves the frame blank.
local map = ns.Art.ZoneMap(env.CreateFrame("Frame"), 174, 116)
local overlays = ns.ClientData.mapOverlays[1413]
assert(overlays and #overlays > 0, "the generated data lists the Barrens overlays")
assert(ns.Art.SetZoneMap(map, 1413), "a map with art draws")
assert(#map.tiles >= 12 + #overlays, "base tiles and every overlay are placed")
assert(not ns.Art.SetZoneMap(map, 999), "a map without art draws nothing")
for _, texture in ipairs(map.tiles) do
	assert(not texture:IsShown(), "a map without art hides every tile")
end
print("instances: ok")
