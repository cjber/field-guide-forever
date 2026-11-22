-- luacheck: read globals scenario
for _, gamepad in ipairs({ false, true }) do
	scenario("creature unit tooltip progress (gamepad " .. (gamepad and "on" or "off") .. ")", function(sim)
		dofile("tests/sim/forever_core.lua").install(sim)
		sim:login()
		sim:setGamepad(gamepad)

		local ns = sim.loader.addons.FieldGuideForever.ns
		local species = { id = 1201, name = "Snow Leopard", minLevel = 7, maxLevel = 8 }
		ns.Zones = { { id = 1, name = "Dun Morogh", species = { species } } }
		ns.BuildCatalogue()

		local tip = sim.G.GameTooltip
		local creature = {
			name = species.name,
			guid = "Creature-0-1-0-1-1201-0000000001",
			level = species.minLevel,
			creatureType = "Beast",
		}

		local function hover(unit)
			sim:unhoverUnit()
			sim:hoverUnit(unit)
			assert(tip:IsShown() and tip:NumLines() >= 2, "expected a Blizzard unit tooltip")
		end

		local function expectProgress(text)
			assert(tip:GetLeftLine(tip:NumLines() - 1):GetText() == "Field Guide", "missing Field Guide header")
			assert(tip:GetLeftLine(tip:NumLines()):GetText() == text, "expected " .. text)
		end

		hover(creature)
		assert(tip:GetLeftLine(1):GetText() == creature.name, "missing native creature name")
		expectProgress("Not yet in your journal")

		assert(ns.RecordKill(creature.name, species.id, creature.guid), "kill was not recorded")
		hover(creature)
		expectProgress("Research: Discovered · 1 kill")

		hover({ name = "Other player", guid = "Player-1-00000001", level = 8, race = "Dwarf", isPlayer = true })
		assert(tip:GetLeftLine(1):GetText() == "Other player", "missing native player name")
		assert(tip:NumLines() == 2, "player tooltip has extra lines")

		sim:enterCombat()
		hover(creature)
		assert(tip:NumLines() == 2, "a secret creature GUID should add no journal lines")
		sim:unhoverUnit()
		sim:leaveCombat()

		if gamepad then
			sim:gamepadNavigate()
			sim:bindingSetChange()
		end
	end)
end
