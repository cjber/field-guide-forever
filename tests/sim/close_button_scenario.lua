-- luacheck: read globals scenario
-- The journal's close button inherits UIPanelCloseButton, whose click handler closes the panel through HideUIPanel.
-- An addon call to the panel manager writes the gamepad frame bookkeeping under this addon's taint, so the client's
-- next secure gamepad call is refused and blamed on Field Guide Forever, the same path #253 fixed for Show and Hide.
-- The button closes the addon-owned frame itself; the runner's expectNoGamepadTaint judges the result (#371).
scenario("the journal's close button closes it without tainting the gamepad bookkeeping", function(sim)
	dofile("tests/sim/forever_core.lua").install(sim)
	sim:login()
	sim:setGamepad(true)

	sim:slash("/fg")
	local frame = sim.G.FieldGuideForeverFrame
	local closeButton = sim.G.FieldGuideForeverFrameCloseButton
	assert(frame and frame:IsShown() and closeButton, "the journal did not open on /fg")
	sim:click(closeButton)
	assert(not frame:IsShown(), "the journal's close button did not close it")

	-- The client's own focus check, the one that reads the bookkeeping HideUIPanel would have tainted: open and
	-- close a Blizzard panel, and fire the input changes the gamepad action bar refreshes from.
	sim:openBags()
	sim:closeBags()
	sim:gamepadNavigate()
	sim:bindingSetChange()
end)
