-- luacheck: read globals scenario
-- The sample a player drags must occupy exactly the rectangle the first real toast gets. AlertFrameQueueMixin:
-- AdjustAnchors (AlertFrames.lua) puts that toast's BOTTOM on the addon container's TOP with a 10 unit gap, and the
-- container's own place decides where the toast lands; a sample anchored any other way lies about it.
local function close(actual, expected, label)
	assert(
		type(actual) == "number" and math.abs(actual - expected) < 0.01,
		("%s: expected %.2f, got %s"):format(label, expected, tostring(actual))
	)
end

for _, scale in ipairs({ 0.65, 1.0 }) do
	scenario("toast sample matches the first real toast at scale " .. scale, function(sim)
		dofile("tests/sim/forever_core.lua").install(sim)
		sim:loadBlizzard("Blizzard_ManagedFrameSystem")
		sim:loadBlizzard("Blizzard_ActionBar")
		sim:loadBlizzard("Blizzard_OverrideActionBar")
		sim:login()
		local G = sim.G
		G.UIParent:SetScale(scale)
		-- Supply a stacked default bar layout: the simulator has no account Edit Mode settings.
		-- Sizes come from the real Blizzard bar templates, not a fitted action bar height.
		sim:loadBlizzard("Blizzard_EditMode/Camelot/EditModeUtil.lua")
		sim:loadBlizzard("Blizzard_EditMode/Shared/EditModeUtil.lua")
		local height = 0
		for _, name in ipairs({ "MainActionBar", "MultiBarBottomRight", "MultiBarBottomLeft" }) do
			local bar = G[name]
			bar.systemInfo = { isInDefaultPosition = true }
			bar:ClearAllPoints()
			bar:SetPoint("BOTTOM", G.UIParent, "BOTTOM", 0, height)
			bar:Show()
			height = height + bar:GetHeight()
		end
		G.OverrideActionBar:Hide()
		G.ManageFramePositions()
		sim:advance(0.2)
		local anchor = assert(G.FieldGuideForeverToastAnchor, "addon-owned toast anchor exists")
		-- The headless client has no renderer; deliver its first-render event explicitly.
		sim.events.fire("FIRST_FRAME_RENDERED")
		sim:advance(0.1)
		assert(anchor:AreAlertsEnabled(), "the addon container observes all startup readiness events")

		-- A two-species zone: this first silver kill is a milestone but does not complete the zone, so exactly one real
		-- toast is queued through the client's alert system just as a kill does in game.
		local ns = sim.loader.addons.FieldGuideForever.ns
		local species = { id = 1001, name = "Toast fixture", minLevel = 1, maxLevel = 1 }
		local other = { id = 1002, name = "Other fixture", minLevel = 1, maxLevel = 1 }
		local zone = { id = 1454, name = "Orgrimmar", species = { species, other } }
		ns.Zones = { zone }
		ns.BuildCatalogue()
		local guid
		for index = 1, 100000 do
			local candidate = string.format("Creature-0-1-0-1-1001-%010X", index)
			if ns.Model.SpawnTier(candidate) == "silver" then
				guid = candidate
				break
			end
		end
		assert(guid, "the fixture rolls a silver spawn")
		assert(ns.RecordKill(species.name, species.id, guid), "the fixture kill records")
		sim:advance(0.3)
		local system = assert(
			anchor.alertFrameSubSystems and anchor.alertFrameSubSystems[1],
			"a milestone registers the addon's toast subsystem"
		)
		local toast, active = nil, 0
		for frame in system.alertFramePool:EnumerateActive() do
			toast = toast or frame
			active = active + 1
		end
		assert(active == 1 and toast, "the real silver toast is the first and only toast on screen")

		ns.Discovery.ToggleToastMover()
		local mover = assert(G.FieldGuideForeverToastMover, "the placement sample is shown")
		assert(mover:IsShown(), "the placement sample is visible")

		-- Default place: the sample and the real toast are the same rectangle, and it clears every bottom bar.
		close(mover:GetBottom(), toast:GetBottom(), "default sample bottom matches the real toast")
		local toastX = toast:GetCenter()
		local moverX = mover:GetCenter()
		close(moverX, toastX, "default sample centre matches the real toast")
		for _, name in ipairs({ "MainActionBar", "MultiBarBottomRight", "MultiBarBottomLeft" }) do
			local bar = assert(G[name], name .. " exists")
			assert(
				toast:GetBottom() > bar:GetTop(),
				("default real toast bottom %.2f is above %s top %.2f at scale %s"):format(
					toast:GetBottom(),
					name,
					bar:GetTop(),
					scale
				)
			)
		end

		-- Dragging the sample moves the real toast with it: the saved point is the anchor's top, one queue gap
		-- above where the sample's bottom ended up.
		local newX, newBottom = 900, 400
		sim.widgets.dispatch(mover, "OnDragStart")
		mover:ClearAllPoints()
		mover:SetPoint("BOTTOM", G.UIParent, "BOTTOMLEFT", newX, newBottom)
		sim.widgets.dispatch(mover, "OnDragStop")
		sim:advance(0.05)
		close(mover:GetBottom(), newBottom, "the dragged sample stays where the pointer left it")
		close(toast:GetBottom(), mover:GetBottom(), "the dragged real toast follows the sample's bottom")
		close(mover:GetCenter(), toast:GetCenter(), "the dragged real toast follows the sample's centre")
		local saved = assert(ns.db.options.toastPoint, "a drag saves the toast's place")
		assert(saved[1] == "TOP" and saved[2] == "BOTTOMLEFT", "the saved point is the anchor's top from UIParent")
		close(saved[3], newX, "the saved point keeps the sample's centre")
		close(saved[4], newBottom - 10, "the saved point is one queue gap below the sample's bottom")

		-- Dragging to the very top of the screen keeps the real toast on screen: the sample's own height is the
		-- toast's, because it is the same art.
		local uiTop = G.UIParent:GetTop()
		local edgeBottom = uiTop - mover:GetHeight()
		sim.widgets.dispatch(mover, "OnDragStart")
		mover:ClearAllPoints()
		mover:SetPoint("BOTTOM", G.UIParent, "BOTTOMLEFT", G.UIParent:GetWidth() / 2, edgeBottom)
		sim.widgets.dispatch(mover, "OnDragStop")
		sim:advance(0.05)
		close(mover:GetBottom(), edgeBottom, "the sample reaches the top edge")
		close(toast:GetBottom(), edgeBottom, "the real toast follows it to the top edge")
		assert(
			toast:GetTop() <= uiTop + 0.01,
			("the real toast top %.2f stays within UIParent's top %.2f"):format(toast:GetTop(), uiTop)
		)
	end)
end
