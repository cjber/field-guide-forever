local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness({ files = { "Data/CreatureIcons.lua" } })
local ns = harness.ns

local siegeType, siegeFamily = ns.CreatureInfo.Get(2749)
assert(siegeType == 4 and siegeFamily == 0, "pinned NPC metadata resolves the Siege Golem as an elemental")
local chickenType, chickenFamily = ns.CreatureInfo.Get(7392)
assert(chickenType == 1 and chickenFamily == 0, "pinned NPC metadata resolves the Prairie Chicken as a beast")
local absentType, absentFamily = ns.CreatureInfo.Get(-1)
assert(absentType == nil and absentFamily == nil, "unknown NPCs have no fabricated type or family")
print("creature_info: ok")
