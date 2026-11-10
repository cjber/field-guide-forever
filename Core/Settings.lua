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

	local shareTooltip = L["On unless you turn it off. Shares your totals and puts you on Forever Leaderboards."]
	page.AddCheck(panel, L["Share progress with guild and group addon users"], function()
		return ns.db and ns.db.options.statsShare ~= false
	end, function(checked)
		if ns.db then
			ns.db.options.statsShare = checked
		end
		if ns.Stats then
			ns.Stats.SetEnabled(checked)
		end
		if ns.FireProgress then
			ns.FireProgress()
		end
	end, shareTooltip)

	local minimapButtonRow = page.AddCheck(panel, L["Minimap button"], function()
		return ns.db and ns.db.options.minimapButtonHidden ~= true
	end, function(checked)
		if ns.db then
			ns.db.options.minimapButtonHidden = not checked
		end
		ForeverCore.MinimapButton.Refresh()
		if ns.FireProgress then
			ns.FireProgress()
		end
	end, L["Adds a Field Guide button to the minimap."])

	-- The one line the shared page has no row kind for, so the addon draws it itself, under the last row.
	local bindingNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	bindingNote:SetPoint("TOPLEFT", minimapButtonRow, "BOTTOMLEFT", 20, -8)
	bindingNote:SetText(L["The Field Guide button can also be bound in Key Bindings > AddOns."])
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
	ns.core.SafeCall("minimap button", function()
		local spec = {
			name = "FieldGuideForeverMinimapButton",
			-- The addon's own client icon, the same one its journal and leaderboard tab wear.
			icon = ns.icon,
			title = L["Field Guide"],
			binding = "Shift-F",
			subtext = L["Click to browse the field compendium"],
			settings = ns.db.options,
			host = ns,
			safeCall = ns.core.SafeCall,
			onClick = ns.OpenGuide,
		}
		local button = ForeverCore.MinimapButton.Create(spec)
		if button and ns.Tooltip then
			-- The shared button draws its own title-only tooltip; Field Guide then redraws it with the journal's minimum
			-- width. Hooks keep the shared handler's own work rather than replacing it.
			button:HookScript("OnEnter", function(self)
				ns.Tooltip.ShowButton(self, spec)
			end)
			button:HookScript("OnLeave", ns.Tooltip.Hide)
		end
	end)
end)
