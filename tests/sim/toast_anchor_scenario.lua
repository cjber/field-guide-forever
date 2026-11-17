-- luacheck: read globals scenario
for _, scale in ipairs({ 0.65, 1.0 }) do
	scenario("toast anchor above action bars at scale " .. scale, function(sim)
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
		for _, name in ipairs({ "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight" }) do
			local bar = assert(G[name], name .. " exists")
			assert(anchor:GetBottom() > bar:GetTop(), name .. " overlaps toast anchor at scale " .. scale)
		end
	end)
end
