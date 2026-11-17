---@type string, FGNamespace
local _, ns = ...

if ns.broken then
	return
end

-- The settings page's chrome -- the panel, its title, the rows that stack down it and the category registration -- is
-- ForeverCore's UI/SettingsPage.lua. What stays here is Field Guide's own rows, every phrase they show and what each
-- one writes to the saved variables.
local L = ns.L

---@class FGSettingsModule
local SettingsPanel = {}
ns.Settings = SettingsPanel

-- Every checkbox refreshes the window's progress display after it writes, so the option's effect is visible at once.
---@param panel Frame
---@param page table
local function BuildPanel(panel, page)
	page.AddCheck(panel, L["Show undiscovered species"], function()
		return ns.db and ns.db.options.showUndiscovered ~= false
	end, function(checked)
		if ns.db then
			ns.db.options.showUndiscovered = checked
		end
		if ns.FireProgress then
			ns.FireProgress()
		end
	end)

	page.AddCheck(panel, L["Show the records list"], function()
		return ns.db and ns.db.options.showSightingLog ~= false
	end, function(checked)
		if ns.db then
			ns.db.options.showSightingLog = checked
		end
		if ns.FireProgress then
			ns.FireProgress()
		end
	end)

	page.AddCheck(panel, L["Announce newly recorded creatures"], function()
		return ns.db and ns.db.options.discoveryText ~= false
	end, function(checked)
		if ns.db then
			ns.db.options.discoveryText = checked
		end
	end, L["A first kill shows one line at the top of the screen, where an explored area is announced."])

	page.AddCheck(panel, L["Show milestone toasts"], function()
		return ns.db and ns.db.options.milestoneToasts ~= false
	end, function(checked)
		if ns.db then
			ns.db.options.milestoneToasts = checked
		end
	end, L["Silver, gold, shiny, mastery and zone milestones show an achievement toast. Click it to open the journal."])

	page.AddButton(panel, L["Move toasts"], ns.Discovery.ToggleToastMover)
	panel:HookScript("OnHide", ns.Discovery.HideToastMover)
end

function SettingsPanel.Register()
	if SettingsPanel.panel then
		return SettingsPanel.panel
	end
	local category, panel = ForeverCore.SettingsPage.Register(L["Field Guide Forever"], BuildPanel, L, ns.core.SafeCall)
	if not panel then
		return nil
	end
	---@cast panel ForeverSettingsPanel
	-- The page's own heading keeps the words it has always shown; the category and the frame carry the addon's name.
	panel.title:SetText(L["Field Guide Forever options"])
	SettingsPanel.panel, SettingsPanel.category = panel, category
	return panel
end

ns.On("PLAYER_LOGIN", function()
	ns.core.SafeCall("settings", SettingsPanel.Register)
end)
