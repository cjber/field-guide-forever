-- The character key is cached only once the client names the character: a read before that answers the fallback
-- without caching it, so the real key takes over as soon as the name is known.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns

Mock.units.player = ""
assert(ns.CharacterKey() == "Unknown-TestRealm", "an unnamed character reads the fallback key")
Mock.units.player = "Barry"
assert(ns.CharacterKey() == "Barry-TestRealm", "the real key takes over once the client names the character")
Mock.units.player = "Someone"
assert(ns.CharacterKey() == "Barry-TestRealm", "a named key is kept for the session")
print("character_key: ok")
