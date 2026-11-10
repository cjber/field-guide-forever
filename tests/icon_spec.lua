local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness({ files = { "Data/Client.lua", "Data/CreatureIcons.lua" } })
harness.Load("UI/Art.lua")
local ns = harness.ns
local Art = ns.Art

assert(
	Art.SpeciesIcon("Siege Golem", 2749) == "Interface\\Icons\\inv_misc_gear_01.blp",
	"Siege Golem uses its model-derived mechanical icon"
)
assert(Art.SpeciesIcon("Prairie Chicken", 7392) == Art.FAMILY_ICONS.Beast, "beasts use beast art")
assert(
	Art.SpeciesIcon("Nillen Andemar", 222) == "Interface\\Icons\\inv_misc_head_dwarf_01.blp",
	"dwarf NPC uses dwarf art"
)
assert(Art.SpeciesIcon("Gath'Ilzogg", 334) == "Interface\\Icons\\inv_misc_head_orc_01.blp", "orc NPC uses orc art")
assert(
	Art.SpeciesIcon("Murloc Forager", 46) == "Interface\\Icons\\inv_misc_head_murloc_01.blp",
	"murloc uses murloc art"
)
assert(Art.SpeciesIcon("Kobold Vermin", 6) == "Interface\\Icons\\inv_misc_head_kobold_01.blp", "kobold uses kobold art")
assert(
	Art.SpeciesIcon("Billy Maclure", 247) == "Interface\\Icons\\inv_misc_head_human_01.blp",
	"human NPC uses human art"
)
assert(Art.SpeciesIcon("Practice Dummy", 5652) == Art.FAMILY_ICONS.Mechanical, "mechanical fallback uses gear art")
assert(
	Art.SpeciesIcon("Unmapped Creature", -1) == Art.GENERIC_CREATURE_ICON,
	"unmatched NPCs use a neutral creature icon"
)
assert(Art.SpeciesIcon("Deer", 883) == "Interface\\Icons\\inv_babydeer", "a deer shows a deer")
assert(Art.SpeciesIcon("Squirrel", 1412) == "Interface\\Icons\\inv_squirrelardenweald", "a squirrel shows a squirrel")
assert(Art.SpeciesIcon("Toad", 1420) == "Interface\\Icons\\inv_pet_toad_green", "a toad shows a toad")
assert(Art.SpeciesIcon("Rabbit", 721) == "Interface\\Icons\\inv_misc_rabbit", "a rabbit shows a rabbit")
assert(
	Art.SpeciesIcon("Ancient of Lore", 3468) == "Interface\\Icons\\inv_pet_ancientprotector",
	"a treant shows a treant, not a humanoid head"
)
assert(
	Art.SpeciesIcon("Yowler", -1) ~= "Interface\\Icons\\ability_hunter_pet_bat",
	"a keyword matches a whole word, so Yowler is not an owl"
)
assert(Art.SpeciesIcon("Owl", -1) == "Interface\\Icons\\ability_hunter_pet_owl", "an owl shows an owl")
assert(
	Art.SpeciesIcon("Mountain Buzzard", -1) == "Interface\\Icons\\ability_hunter_pet_vulture",
	"a carrion bird shows a carrion bird"
)
print("icon: ok")
