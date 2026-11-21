-- Saved progress is keyed by ForeverCore.CharacterKey: "Name Surname-<server>" on a Forever realm, which has no realm
-- name, and "Name-Realm" on a named realm. Nil until the client names the character, kept once known. Saves keyed
-- "Name-Unknown" or "Name-<display realm>" before it are adopted.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")

local function Loaded(chars, realm)
	local harness = Mock.Harness()
	Mock.units.player = "Alex"
	Mock.realm = realm or ""
	harness.env.FieldGuideForeverDB = { version = harness.ns.SCHEMA, chars = chars }
	harness:Fire("ADDON_LOADED", "FieldGuideForever")
	harness:RunTimers()
	return harness.ns
end

local harness = Mock.Harness()
local ns = harness.ns
Mock.units.player = ""
assert(ns.CharacterKey() == nil, "an unnamed character has no key")
Mock.units.player = "Alex"
assert(ns.CharacterKey() == "Alex Ironhide-6941", "a Forever character is keyed by name, surname and server")
Mock.units.player = "Someone"
assert(ns.CharacterKey() == "Alex Ironhide-6941", "the key is kept for the session")

-- A Forever save under the old shared "Name-Unknown" key: each character with that first name starts from a copy.
local old = { species = { [1001] = { kills = 3 } }, encounters = {} }
ns = Loaded({ ["Alex-Unknown"] = old })
local state = ns.GetCharacterState(false)
assert(state and state.species[1001].kills == 3, "the old progress is adopted")
local shared = ns.db.chars["Alex-Unknown"]
assert(shared and shared ~= state, "the shared record stays for the other Barrys, as a separate copy")
state.species[1001].kills = 4
assert(shared.species[1001].kills == 3, "and progress after it is this character's own")

-- A named realm's old "Name-Display Realm" record is this character's alone: it moves.
local named = { species = { [1002] = { kills = 1 } }, encounters = {} }
ns = Loaded({ ["Alex-Pyrewood Village"] = named }, "Pyrewood Village")
assert(ns.CharacterKey() == "Alex-PyrewoodVillage", "a named realm keeps the normalized Name-Realm key")
local moved = ns.GetCharacterState(false)
assert(moved and moved.species[1002].kills == 1, "its old record moves to the new key")
assert(ns.db.chars["Alex-Pyrewood Village"] == nil, "and leaves the old one")
Mock.Reset()

print("character_key: ok")
