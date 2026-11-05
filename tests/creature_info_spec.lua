local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness({ files = { "Data/CreatureIcons.lua" } })
local ns = harness.ns

local siegeType, siegeFamily, siegeIcon, siegeDisplay = ns.CreatureInfo.Get(2749)
assert(siegeType == 4 and siegeFamily == 0, "pinned NPC metadata resolves the Siege Golem as an elemental")
assert(siegeIcon == "interface/icons/inv_misc_gear_01.blp", "the model icon keeps its generated path")
assert(siegeDisplay == 13869, "the same entry carries the client display ID for a live portrait")
local chickenType, chickenFamily = ns.CreatureInfo.Get(7392)
assert(chickenType == 1 and chickenFamily == 0, "pinned NPC metadata resolves the Prairie Chicken as a beast")
local absentType, absentFamily, absentIcon, absentDisplay = ns.CreatureInfo.Get(-1)
assert(absentType == nil and absentFamily == nil, "unknown NPCs have no fabricated type or family")
assert(absentIcon == nil and absentDisplay == nil, "unknown NPCs have no fabricated icon or display ID")
print("creature_info: ok")
