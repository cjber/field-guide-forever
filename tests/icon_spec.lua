local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness({ files = { "Data/Client.lua", "Data/CreatureIcons.lua" } })
harness.Load("UI/Art.lua")
local ns = harness.ns
local Art = ns.Art

assert(
	Art.SpeciesIcon("Siege Golem", 2749) == Art.FAMILY_ICONS.Elemental,
	"Siege Golem uses the source's elemental type"
)
assert(Art.SpeciesIcon("Prairie Chicken", 7392) == Art.FAMILY_ICONS.Beast, "beasts use beast art")
assert(Art.SpeciesIcon("Jarkal Mossmeld", 6868) == Art.FAMILY_ICONS.Humanoid, "humanoids use humanoid art")
local mechanicalID
for npcID, packed in pairs(ns.CreatureInfo.entries) do
	if math.floor(packed / 65536) == 9 then
		mechanicalID = npcID
		break
	end
end
assert(mechanicalID, "generated data includes a mechanical NPC")
assert(
	Art.SpeciesIcon("Fixture Machine", mechanicalID) == "Interface\\Icons\\INV_Misc_Gear_01",
	"mechanicals use mechanical art"
)
assert(
	Art.SpeciesIcon("Unmapped Creature", -1) == Art.GENERIC_CREATURE_ICON,
	"unmatched NPCs use a neutral creature icon"
)
print("icon: ok")
