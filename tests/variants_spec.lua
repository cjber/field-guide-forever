-- The journal's tier ladder: one best-coat marker per list row, the zone and all-zones header totals, and the
-- silver, gold, shiny and missing-shiny filters.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local npcFixture = {
	[1001] = { name = "Plainstrider", minLevel = 1, maxLevel = 2, rank = 0, subName = "Beast", zoneID = 17 },
	[1003] = { name = "Savannah Prowler", minLevel = 9, maxLevel = 10, rank = 0, subName = "Beast", zoneID = 17 },
	[1019] = { name = "Dishu", minLevel = 13, maxLevel = 13, rank = 2, subName = "Beast", zoneID = 17 },
	[1025] = { name = "Silver Test", minLevel = 4, maxLevel = 5, rank = 0, subName = "Beast", zoneID = 17 },
	[1030] = { name = "Undiscovered Test", minLevel = 2, maxLevel = 3, rank = 0, subName = "Beast", zoneID = 17 },
}
harness.env.LibQuestieDB = {
	Npc = {
		GetAllIds = function()
			return { 1001, 1003, 1019, 1025, 1030 }
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
local function Record(id, tier)
	ns.Model.Record(state, id, { tier = tier, species = ns.SpeciesById[id] })
end
Record(1001, "shiny")
Record(1003, "bronze")
Record(1019, "gold")
Record(1025, "silver")

Window.Show()
-- The journal opens on Discovered; this spec also checks the undiscovered row and the coat filters.
Window.SetFilter("all")
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

-- Every row carries one marker: the quality mark of the best variant found. Bronze shows nothing.
local plainstrider, prowler = Row("Plainstrider"), Row("Savannah Prowler")
local dishu, silver = Row("Dishu"), Row("Silver Test")
local undiscovered = Row("Undiscovered Test")
assert(plainstrider and prowler and dishu and silver and undiscovered, Names())
assert(plainstrider.Mark:GetAtlas() == "Professions-Icon-Quality-Tier4", "a shiny row carries the fourth mark")
assert(silver.Mark:GetAtlas() == "Professions-Icon-Quality-Tier2", "a silver row carries the second mark")
assert(dishu.Mark:GetAtlas() == "Professions-Icon-Quality-Tier3", "a gold row carries the third mark")
assert(not prowler.Mark:IsShown(), "a bronze row leaves the marker empty")
assert(not undiscovered.Mark:IsShown(), "an undiscovered row leaves the marker empty")

-- The bottom bar counts this zone's species with each standout variant.
assert(Window.totals.silver.value:GetText() == "1", Window.totals.silver.value:GetText())
assert(Window.totals.gold.value:GetText() == "1", Window.totals.gold.value:GetText())
assert(Window.totals.shiny.value:GetText() == "1", Window.totals.shiny.value:GetText())

-- Filters pick species by the coats this character has found.
Window.SetFilter("silver")
assert(Names() == "Silver Test", Names())
Window.SetFilter("gold")
assert(Names() == "Dishu", Names())
Window.SetFilter("shiny")
assert(Names() == "Plainstrider", Names())
Window.SetFilter("missingShiny")
assert(Names() == "Dishu,Savannah Prowler,Silver Test,Undiscovered Test", Names())
Window.SetFilter("all")
print("variants: ok")
