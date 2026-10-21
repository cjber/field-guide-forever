---@type string, BFNamespace
local _, ns = ...
local L = ns.L

local SettingsPanel = {}
ns.Settings = SettingsPanel

---@param panel Frame
---@param text string
---@param y number
---@param get fun(): boolean
---@param set fun(checked: boolean)
local function CheckButton(panel, text, y, get, set)
	local check = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	check:SetPoint("TOPLEFT", 16, y)
	check:SetChecked(get() == true)
	local label = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("LEFT", check, "RIGHT", 4, 0)
	label:SetText(text)
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
	panel.name = L["Bestiary Forever"]

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(L["Bestiary Forever options"])

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

	return panel
end

function SettingsPanel.Register()
	if SettingsPanel.panel then
		return SettingsPanel.panel
	end
	local panel = BuildPanel()
	SettingsPanel.panel = panel
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, L["Bestiary Forever"])
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	return panel
end

ns.On("PLAYER_LOGIN", function()
	ns.SafeCall("settings", SettingsPanel.Register)
end)
