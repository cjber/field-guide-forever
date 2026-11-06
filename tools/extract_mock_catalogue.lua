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
		local spawns, spawnPoints = {}, {}
		if type(values[7]) == "table" then
			for zoneId, points in pairs(values[7]) do
				if tonumber(zoneId) then
					spawns[#spawns + 1] = tonumber(zoneId)
					-- The screenshots draw the same habitat pins the journal draws, so keep each point with its area.
					if type(points) == "table" then
						for _, point in ipairs(points) do
							local x = type(point) == "table" and tonumber(point[1])
							local y = type(point) == "table" and tonumber(point[2])
							if x and y then
								spawnPoints[#spawnPoints + 1] = string.format("%d:%.2f:%.2f", tonumber(zoneId), x, y)
							end
						end
					end
				end
			end
		end
		local zoneId = tonumber(values[6])
		if zoneId then
			spawns[#spawns + 1] = zoneId
		end
		table.sort(spawns)
		table.sort(spawnPoints)
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
				table.concat(spawnPoints, ";"),
			}, "\t"),
			"\n"
		)
	end
end
file:close()
