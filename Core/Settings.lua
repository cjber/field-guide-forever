---@type string, FGNamespace
local _, ns = ...
local L = ns.L

local SettingsPanel = {}
ns.Settings = SettingsPanel

---@param panel Frame
---@param text string
---@param y number
---@param get fun(): boolean
---@param set fun(checked: boolean)
local function CheckButton(panel, text, y, get, set, tooltip)
	local check = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	check:SetPoint("TOPLEFT", 16, y)
	check:SetChecked(get() == true)
	local label = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("LEFT", check, "RIGHT", 4, 0)
	label:SetText(text)
	if tooltip then
		check.tooltipText = tooltip
	end
	check:SetScript("OnClick", function(self)
		set(self:GetChecked() == true)
		if ns.FireProgress then
			ns.FireProgress()
		end
	end)
end

---@return Frame
local function BuildPanel()
	local panel = CreateFrame("Frame")
	panel.name = L["Field Guide Forever"]

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(L["Field Guide Forever options"])

	CheckButton(panel, L["Show undiscovered species"], -48, function()
		return ns.db and ns.db.options.showUndiscovered ~= false
	end, function(checked)
		if ns.db then
			ns.db.options.showUndiscovered = checked
		end
	end)

	CheckButton(panel, L["Show the sighting log"], -80, function()
		return ns.db and ns.db.options.showSightingLog ~= false
	end, function(checked)
		if ns.db then
			ns.db.options.showSightingLog = checked
		end
	end)

	CheckButton(panel, L["Share progress with guild and group addon users"], -112, function()
		return ns.db and ns.db.options.statsShare ~= false
	end, function(checked)
		if ns.db then
			ns.db.options.statsShare = checked
		end
		if ns.Stats then
			ns.Stats.SetEnabled(checked)
		end
	end)

	CheckButton(panel, L["Show the Field Guide micro menu button"], -144, function()
		return ns.db and ns.db.options.microButton ~= false
	end, function(checked)
		if ns.db then
			ns.db.options.microButton = checked
		end
		if ns.MicroButton then
			ns.MicroButton.Refresh()
		end
	end, L["Adds a Field Guide button to the micro menu bar."])

	local bindingNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	bindingNote:SetPoint("TOPLEFT", 36, -178)
	bindingNote:SetText(L["Both buttons can also be bound in Key Bindings > AddOns."])

	return panel
end

function SettingsPanel.Register()
	if SettingsPanel.panel then
		return SettingsPanel.panel
	end
	local panel = BuildPanel()
	SettingsPanel.panel = panel
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, L["Field Guide Forever"])
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	return panel
end

ns.On("PLAYER_LOGIN", function()
	ns.SafeCall("settings", SettingsPanel.Register)
	ns.SafeCall("micro button", function()
		ns.MicroButton.Create({
			name = "FieldGuideForeverMicroButton",
			atlas = "Questlog",
			icon = "Interface\\Icons\\inv_misc_book_09",
			title = L["Field Guide"],
			binding = "Shift-F",
			subtext = L["Click to browse the field compendium"],
			slot = "beforeGameMenu",
			host = ns,
			getShown = function()
				return ns.db and ns.db.options.microButton ~= false
			end,
			onClick = ns.OpenGuide,
		})
	end)
end)
