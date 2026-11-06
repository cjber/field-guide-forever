-- The journal list shows each creature's real client portrait when the catalogue knows its display ID, and the
-- species fallback art when it does not. Only the visible rows are kept, so a long list recycles one pool.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local npcFixture = {
	[883] = { name = "Deer", minLevel = 1, maxLevel = 1, rank = 0, subName = "Critter", zoneID = 17 },
	[3468] = { name = "Ancient of Lore", minLevel = 62, maxLevel = 62, rank = 0, subName = "Humanoid", zoneID = 17 },
	[90001] = { name = "No Portrait", minLevel = 1, maxLevel = 1, rank = 0, subName = "Beast", zoneID = 17 },
}
harness.env.LibQuestieDB = {
	Npc = {
		GetAllIds = function()
			return { 883, 3468, 90001 }
		end,
		GetAll = function(id, fields)
			local row, values = npcFixture[id], {}
			for _, field in ipairs(fields) do
				values[#values + 1] = field == "spawns" and { [17] = {} } or row[field]
			end
			return values
		end,
	},
}
harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")
harness:RunTimers()
local ns, Window, List = harness.ns, harness.ns.Window, harness.ns.List
Window.Show()
-- The journal opens on Discovered; this spec is about every icon, so show the whole zone.
Window.SetFilter("all")

local function Row(name)
	for _, row in ipairs(List.rows) do
		if row:IsShown() and row.species and row.species.name == name then
			return row
		end
	end
end

local deer = assert(Row("Deer"), "Deer is in the Barrens list")
local _, _, _, deerDisplay = ns.CreatureInfo.Get(883)
assert(deerDisplay and deer.Icon.portraitDisplayID == deerDisplay, "Deer draws its real client portrait")
assert(rawget(deer.Icon, "_texture") == nil, "a portrait replaces the fallback icon instead of layering over it")

local treant = assert(Row("Ancient of Lore"), "Ancient of Lore is in the list")
local _, _, _, treantDisplay = ns.CreatureInfo.Get(3468)
assert(treantDisplay and treant.Icon.portraitDisplayID == treantDisplay, "a treant also draws its real portrait")

local noPortrait = assert(Row("No Portrait"), "an unmapped NPC still gets a row")
assert(rawget(noPortrait.Icon, "portraitDisplayID") == nil, "no display ID means no portrait call")
assert(noPortrait.Icon._texture == ns.Art.SpeciesIcon("No Portrait", 90001), "the fallback icon is the species art")

-- A hundred entries keep a viewport-sized pool; scrolling updates that pool in place.
local many = {}
for index = 1, 100 do
	many[index] = {
		species = { id = -1000 - index, name = "Synthetic " .. index, family = "Beast", minLevel = 1, maxLevel = 1 },
	}
end
List.Refresh(many, many[1].species.id)
assert(#List.rows < 100, "the list keeps a small recycled pool: " .. #List.rows)
assert(List.rows[1].species == many[1].species, "the first row starts at the top")
List.scroll:SetVerticalScroll(55 * 20)
List.scroll:GetScript("OnVerticalScroll")()
assert(List.rows[1].species == many[21].species, "scrolling reuses the same rows for the next screen")
print("list icons: ok")
