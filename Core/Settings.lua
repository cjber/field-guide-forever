---@type string, FGNamespace
local _, ns = ...

-- The settings page's chrome -- the panel, its title, the rows that stack down it and the category registration -- is
-- Forever Core's UI/SettingsPage.lua, vendored byte for byte. What stays here is Field Guide's own rows, every phrase
-- they show and what each one writes to the saved variables.
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
	end)

	local microButtonRow = page.AddCheck(panel, L["Show the Field Guide micro menu button"], function()
		return ns.db and ns.db.options.microButton ~= false
	end, function(checked)
		if ns.db then
			ns.db.options.microButton = checked
		end
		if ns.MicroButton then
			ns.MicroButton.Refresh()
		end
		if ns.FireProgress then
			ns.FireProgress()
		end
	end, L["Adds a Field Guide button to the micro menu bar."])

	-- The one line the shared page has no row kind for, so the addon draws it itself, under the last row.
	local bindingNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	bindingNote:SetPoint("TOPLEFT", microButtonRow, "BOTTOMLEFT", 20, -8)
	bindingNote:SetText(L["Both buttons can also be bound in Key Bindings > AddOns."])
end

function SettingsPanel.Register()
	if SettingsPanel.panel then
		return SettingsPanel.panel
	end
	local category, panel = ns.SettingsPage.Register(L["Field Guide Forever"], BuildPanel)
	if not panel then
		return nil
	end
	-- The page's own heading keeps the words it has always shown; the category and the frame carry the addon's name.
	panel.title:SetText(L["Field Guide Forever options"])
	SettingsPanel.panel, SettingsPanel.category = panel, category
	return panel
end

ns.On("PLAYER_LOGIN", function()
	ns.SafeCall("settings", SettingsPanel.Register)
	ns.SafeCall("micro button", function()
		local glyph = "Interface\\AddOns\\FieldGuideForever\\media\\MicroGlyph"
		local glyphHover = "Interface\\AddOns\\FieldGuideForever\\media\\MicroGlyphHover"
		local spec = {
			name = "FieldGuideForeverMicroButton",
			atlas = "ButtonBG",
			icon = glyph,
			title = L["Field Guide"],
			binding = "Shift-F",
			subtext = L["Click to browse the field compendium"],
			slot = "beforeGameMenu",
			host = ns,
			getShown = function()
				return ns.db and ns.db.options.microButton ~= false
			end,
			onClick = ns.OpenGuide,
		}
		local button = ns.MicroButton.Create(spec)
		if button then
			-- The shared button puts the glyph on the native plate. Hover and the pressed offset are the native
			-- micro-menu behaviours, added here so the shared module stays in step with Forever Core.
			local micro = button --[[@as ForeverMicroButton]]
			local hover = micro:CreateTexture(nil, "HIGHLIGHT")
			hover:SetTexture(glyphHover)
			hover:SetSize(22, 22)
			hover:SetPoint("CENTER", 0, 0.5)
			hover:SetBlendMode("ADD")
			local icon = micro.icon
			-- The plate is the button's normal texture on ARTWORK, the glyph's own layer, so it could draw over the
			-- glyph; OVERLAY keeps the glyph on top in every state.
			icon:SetDrawLayer("OVERLAY")
			local function Offset(down)
				icon:ClearAllPoints()
				icon:SetPoint("CENTER", 0, down and -0.5 or 0.5)
			end
			micro:HookScript("OnMouseDown", function()
				Offset(true)
			end)
			micro:HookScript("OnMouseUp", function()
				Offset(false)
			end)
			micro:HookScript("OnLeave", function()
				Offset(false)
			end)
			micro:HookScript("OnHide", function()
				Offset(false)
			end)
		end
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
