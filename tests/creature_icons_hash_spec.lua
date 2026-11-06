-- The creature icon header hash pins the QuestieDB NPC id set, not the fixture bytes, which differ by Lua build and
-- locale. The generator is Python, so ask it for the hash the same way it writes the header.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local tools = Mock.Root() .. "tools"

local function catalogueHash(ids)
	local script = table.concat({
		"import sys",
		"sys.path.insert(0, sys.argv[1])",
		"from gen_creature_icons import catalogue_hash",
		"print(catalogue_hash({int(value) for value in sys.argv[2:]}))",
	}, "; ")
	local command = table.concat({ "python3", "-c", string.format("%q", script), string.format("%q", tools) }, " ")
	for _, id in ipairs(ids) do
		command = command .. " " .. id
	end
	local pipe = assert(io.popen(command, "r"))
	local output = pipe:read("*a")
	assert(pipe:close(), "python3 could not compute the catalogue hash")
	return (output:gsub("%s+$", ""))
end

local ordered = catalogueHash({ 4, 1, 3, 2 })
assert(ordered == catalogueHash({ 2, 4, 3, 1 }), "the same NPC id set in a different order hashes the same")
assert(ordered ~= catalogueHash({ 1, 2, 3, 5 }), "a changed NPC id changes the hash")
print("creature_icons_hash: ok")
