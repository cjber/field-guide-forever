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

-- A realm the client cannot name yet keeps the character's own name in the fallback key, and caches nothing.
local second = Mock.Harness()
local realm = nil
second.env.GetRealmName = function()
	return realm
end
Mock.units.player = "Barry"
assert(second.ns.CharacterKey() == "Barry-Unknown", "a missing realm keeps the named character")
realm = "TestRealm"
assert(second.ns.CharacterKey() == "Barry-TestRealm", "the real key takes over once the realm is known")
print("character_key: ok")
