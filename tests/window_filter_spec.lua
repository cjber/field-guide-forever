-- The journal opens on Discovered: its filter button says so, a new character gets a helpful empty list instead
-- of a blank one, and an undiscovered species stays out until the filter is widened.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns

harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")

local function species(id, name)
	return { id = id, name = name, family = "Beast", minLevel = 1, maxLevel = 1, spawns = {} }
end
ns.Zones = {
	{
		id = 17,
		name = "The Barrens",
		continent = "Kalimdor",
		species = { species(1001, "Plainstrider"), species(1002, "Savannah Prowler") },
	},
}
ns.BuildCatalogue()
ns.catalogueStatus = "ok"
ns.db.chars[ns.CharacterKey()] = { species = {} }

ns.Window.Show()
assert(ns.Window.filterButton.Label:GetText() == "Discovered", "the filter button starts on Discovered")
assert(#ns.List.entries == 0, "a new character has nothing in the Discovered list")
assert(ns.List.empty:IsShown(), "the empty list explains itself")
assert(
	ns.List.empty:GetText()
		== "Nothing discovered here yet. Defeat a creature or hover its nameplate to add it to your journal.",
	"the empty state names the journal action: " .. ns.List.empty:GetText()
)

local state = ns.GetCharacterState()
ns.Model.Record(state, 1001, { tier = "bronze" })
ns.Window.Refresh()
assert(#ns.List.entries == 1 and ns.List.entries[1].species.id == 1001, "only the discovered species is listed")
assert(not ns.List.empty:IsShown(), "a non-empty list hides the empty state")

ns.Window.SetFilter("all")
assert(#ns.List.entries == 2, "showing All brings the undiscovered species back")
assert(ns.List.empty:IsShown() == false, "the all filter keeps the list alive")
print("window filter: ok")
