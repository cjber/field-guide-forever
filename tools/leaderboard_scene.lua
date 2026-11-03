-- Render the actual slash output, including a personal row below the top ten.
local Mock = dofile("tests/wow_mock.lua")
local h = Mock.Harness()
h:Fire("ADDON_LOADED", "FieldGuideForever")
h.ns.catalogueStatus = "ok"
h.ns.GetCharacterState().species[42] = { kills = 5, count = 5 }
for index = 1, 12 do
	h:Fire(
		"CHAT_MSG_ADDON",
		"WFAStats",
		"1|fieldguide|creature_kills|all|" .. (20 + index) .. "|900",
		"GUILD",
		"Example" .. index .. "-Other"
	)
end
h.env.print = function(line)
	print(line)
end
h.env.SlashCmdList.FIELDGUIDEFOREVER("leaderboard")
