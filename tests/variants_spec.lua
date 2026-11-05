-- The three collectible forms in the journal: the marks on every list row, the zone and all-zones totals in the
-- header, and the "Missing shiny" and "Missing rare" filters. A species that can never be rare has no rare form: an
-- empty slot, never missing, never counted.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local npcFixture = {
	[1001] = { name = "Plainstrider", minLevel = 1, maxLevel = 2, rank = 0, subName = "Beast", zoneID = 17 },
	[1003] = { name = "Savannah Prowler", minLevel = 9, maxLevel = 10, rank = 0, subName = "Beast", zoneID = 17 },
	[1019] = { name = "Dishu", minLevel = 13, maxLevel = 13, rank = 2, subName = "Beast", zoneID = 17 },
}
harness.env.LibQuestieDB = {
	Npc = {
		GetAllIds = function()
			return { 1001, 1003, 1019 }
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
local state = ns.GetCharacterState(true)
local function Kill(id, shiny)
	ns.Model.Record(state, id, {
		species = ns.SpeciesById[id],
		random = function()
			return shiny and 0 or 0.9
		end,
	})
end
Kill(1001, true)
Kill(1019)
assert(ns.GetCharacterState(false).species[1001].shiny == 1, "the fixture shiny is recorded")

Window.Show()
local function Row(name)
	for _, row in ipairs(List.rows) do
		if row:IsShown() and row.species and row.species.name == name then
			return row
		end
	end
end
local function Names()
	local names = {}
	for _, row in ipairs(List.rows) do
		if row:IsShown() and row.species then
			names[#names + 1] = row.species.name
		end
	end
	table.sort(names)
	return table.concat(names, ",")
end

-- Every row carries three marks: lit when collected, dark while missing, an empty slot with no rare form.
local plainstrider, dishu = Row("Plainstrider"), Row("Dishu")
assert(plainstrider and dishu, Names())
assert(plainstrider.Marks.common:IsShown() and plainstrider.Marks.common.Icon._vertexColor[1] == 1)
assert(not plainstrider.Marks.rare:IsShown(), "no rare form leaves the rare slot empty")
assert(plainstrider.Marks.shiny.Star:IsShown() and plainstrider.Marks.shiny.Star._vertexColor[1] > 0.8)
assert(dishu.Marks.rare:IsShown() and dishu.Marks.rare.Border.atlas == "loottoast-itemborder-blue")
assert(dishu.Marks.rare.Icon._vertexColor[1] < 1, "a missing rare is dark")
assert(dishu.Marks.shiny.Star._vertexColor[1] < 0.5, "a missing shiny is dark")

-- Totals: only Dishu can be rare; all three can be shiny.
local zone = Window.totals.zone
assert(zone.label:GetText() == "The Barrens", zone.label:GetText())
assert(zone.values:GetText() == "Rare 0 / 1 · Shiny 1 / 3", zone.values:GetText())
assert(Window.totals.all.values:GetText() == "Rare 0 / 1 · Shiny 1 / 3", Window.totals.all.values:GetText())

-- Missing shiny keeps the two without one; missing rare keeps only Dishu, never a species with no rare form.
Window.SetFilter("missingShiny")
assert(Names() == "Dishu,Savannah Prowler", Names())
Window.SetFilter("missingRare")
assert(Names() == "Dishu", Names())
Kill(1019)
Kill(1019)
Window.Refresh()
assert(Names() == "", "a collected rare leaves the missing rare filter: " .. Names())
assert(zone.values:GetText() == "Rare 1 / 1 · Shiny 1 / 3", zone.values:GetText())
Window.SetFilter("all")
print("variants: ok")
