-- Extracts a temporary visual fixture from the pinned QuestieDB release in tools/.cache.
-- This fixture is never shipped; the addon reads the installed shared database at runtime.
local root, output = assert(arg[1]), assert(arg[2])
local loadQuestieDB = dofile("tools/questiedb_load.lua")
local lib = loadQuestieDB(root, "QuestieDB_Forever.toc")
local file = assert(io.open(output, "w"))
local fields = { "name", "minLevel", "maxLevel", "rank", "subName", "zoneID", "spawns" }
local ids = lib.Npc.GetAllIds()
table.sort(ids)
local function clean(value)
	return tostring(value or ""):gsub("[\t\r\n]", " ")
end
for _, id in ipairs(ids) do
	local values = lib.Npc.GetAll(id, fields)
	if type(values) == "table" and type(values[1]) == "string" and values[1] ~= "" then
		local spawns = {}
		if type(values[7]) == "table" then
			for zoneId in pairs(values[7]) do
				if tonumber(zoneId) then
					spawns[#spawns + 1] = tonumber(zoneId)
				end
			end
		end
		local zoneId = tonumber(values[6])
		if zoneId then
			spawns[#spawns + 1] = zoneId
		end
		table.sort(spawns)
		local zones, previous = {}, nil
		for _, spawnId in ipairs(spawns) do
			if spawnId ~= previous then
				zones[#zones + 1] = spawnId
				previous = spawnId
			end
		end
		file:write(
			table.concat({
				id,
				clean(values[1]),
				clean(values[2]),
				clean(values[3]),
				clean(values[4]),
				clean(values[5]),
				table.concat(zones, ","),
			}, "\t"),
			"\n"
		)
	end
end
file:close()
