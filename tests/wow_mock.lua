-- A headless client good enough for the specs: frames are inert tables, events are delivered by hand, and the combat
-- log is whatever the spec placed in Mock.combatLog. Nothing here is loaded by the addon.

local Mock = {}

Mock.zone = "The Barrens"
Mock.clock = 1000
Mock.frames = {}
Mock.eventFrames = {}
Mock.named = {}
Mock.timers = {}
Mock.combatLog = nil

---@param path string
---@return boolean
local function exists(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	end
	return false
end

---@return string
function Mock.Root()
	for _, prefix in ipairs({ "", "../", "../../" }) do
		if exists(prefix .. "BestiaryForever.toc") then
			return prefix
		end
	end
	return ""
end

---@return string[]
function Mock.TocFiles()
	local files = {}
	local file = io.open(Mock.Root() .. "BestiaryForever.toc", "r")
	if not file then
		return files
	end
	for line in file:lines() do
		local name = line:match("^%s*([^#].-%.lua)%s*$")
		if name then
			files[#files + 1] = name:gsub("\\", "/")
		end
	end
	file:close()
	return files
end

function Mock.Reset()
	Mock.zone = "The Barrens"
	Mock.clock = 1000
	Mock.frames = {}
	Mock.eventFrames = {}
	Mock.named = {}
	Mock.timers = {}
	Mock.combatLog = nil
end

local methods = {}

---@param kind string
---@param name string?
---@param parent Frame?
---@param template string?
---@return Frame
local function NewRegion(kind, name, parent, template)
	local region = {
		_type = kind,
		_name = name,
		_parent = parent,
		_template = template,
		_scripts = {},
		_events = {},
		_text = "",
		_shown = true,
		_enabled = true,
		_width = 100,
		_height = 20,
		_alpha = 1,
		_scale = 1,
		_points = {},
		_id = 0,
		_checked = false,
	}
	return setmetatable(region, { __index = methods })
end

Mock.NewRegion = NewRegion

function methods:SetScript(event, fn)
	self._scripts[event] = fn
end

function methods:GetScript(event)
	return self._scripts[event]
end

function methods:HookScript(event, fn)
	self._scripts[event] = self._scripts[event] or fn
end

function methods:RegisterEvent(event)
	self._events[event] = true
	Mock.eventFrames[event] = Mock.eventFrames[event] or {}
	for _, frame in ipairs(Mock.eventFrames[event]) do
		if frame == self then
			return
		end
	end
	table.insert(Mock.eventFrames[event], self)
end

function methods:UnregisterEvent(event)
	self._events[event] = nil
end

function methods:CreateFontString(name, _layer, font)
	return NewRegion("FontString", name, self, font)
end

function methods:CreateTexture(name, layer)
	return NewRegion("Texture", name, self, layer)
end

function methods:CreateMaskTexture()
	return NewRegion("MaskTexture", nil, self)
end

function methods.AddMaskTexture() end

function methods.SetMaskTexture() end

function methods:GetName()
	return self._name
end

function methods:GetParent()
	return self._parent
end

function methods:GetID()
	return self._id
end

function methods:SetID(id)
	self._id = id
end

function methods:IsShown()
	return self._shown
end

function methods:IsVisible()
	return self._shown
end

function methods:Show()
	self._shown = true
end

function methods:Hide()
	self._shown = false
end

function methods:SetShown(shown)
	self._shown = shown and true or false
end

function methods:SetText(text)
	self._text = tostring(text or "")
end

function methods:GetText()
	return self._text
end

function methods:SetFormattedText(format, ...)
	self._text = string.format(format, ...)
end

function methods:GetStringWidth()
	return #self._text * 6
end

function methods:SetWidth(width)
	self._width = width
end

function methods:SetHeight(height)
	self._height = height
end

function methods:SetSize(width, height)
	self._width, self._height = width, height
end

function methods:GetWidth()
	return self._width
end

function methods:GetHeight()
	return self._height
end

function methods:GetSize()
	return self._width, self._height
end

function methods:SetPoint(point, relativeTo, relativePoint, x, y)
	self._points[#self._points + 1] = { point, relativeTo, relativePoint, x or 0, y or 0 }
end

function methods:GetPoint(index)
	local point = self._points[index or 1]
	if point then
		return point[1], point[2], point[3], point[4], point[5]
	end
	return "CENTER", nil, "CENTER", 0, 0
end

function methods:ClearAllPoints()
	self._points = {}
end

function methods:GetNumPoints()
	return #self._points
end

function methods.SetAllPoints() end

function methods:SetChecked(checked)
	self._checked = checked and true or false
end

function methods:GetChecked()
	return self._checked
end

function methods:SetEnabled(enabled)
	self._enabled = enabled
end

function methods:IsEnabled()
	return self._enabled
end

function methods:Enable()
	self._enabled = true
end

function methods:Disable()
	self._enabled = false
end

function methods:SetAlpha(alpha)
	self._alpha = alpha
end

function methods:GetAlpha()
	return self._alpha
end

function methods:SetScale(scale)
	self._scale = scale
end

function methods:GetScale()
	return self._scale
end

function methods:GetEffectiveScale()
	return self._scale
end

function methods.GetCenter()
	return 0, 0
end

function methods:SetFrameStrata(strata)
	self._strata = strata
end

function methods:SetFrameLevel(level)
	self._level = level
end

function methods:GetFrameLevel()
	return self._level or 1
end

function methods.StartMoving() end

function methods.StopMovingOrSizing() end

function methods.RegisterForDrag() end

function methods.SetMovable() end

function methods.SetClampedToScreen() end

function methods.EnableMouse() end

function methods.SetToplevel() end

function methods.SetAutoFocus() end

function methods.SetMaxLetters() end

function methods.SetTextInsets() end

function methods:SetFontObject(font)
	self._font = font
end

function methods:GetFontObject()
	return self._font
end

function methods.SetJustifyH() end

function methods.SetJustifyV() end

function methods.SetWordWrap() end

function methods.SetSpacing() end

function methods.SetTextColor() end

function methods.SetVertexColor() end

function methods:SetTexture(texture)
	self._texture = texture
end

function methods.SetTexCoord() end

function methods.SetDesaturated() end

function methods.SetDrawLayer() end

function methods.SetHitRectInsets() end

function methods:SetScrollChild(child)
	self._scrollChild = child
end

function methods.SetVerticalScroll() end

function methods.SetBackdrop() end

function methods.SetBackdropColor() end

function methods.SetBackdropBorderColor() end

function methods.SetHighlightTexture() end

function methods.SetNormalTexture() end

function methods.SetPushedTexture() end

function methods.GetRegions()
	return {}
end

function methods.GetChildren()
	return {}
end

function methods.ClearFocus() end

function methods.SetFocus() end

function methods:SetParent(parent)
	self._parent = parent
end

setmetatable(methods, {
	__index = function()
		return function()
			return nil
		end
	end,
})

---@param kind string
---@param name string?
---@param parent Frame?
---@param template string?
---@return Frame
function Mock.CreateFrame(kind, name, parent, template)
	local frame = NewRegion(kind, name, parent, template)
	Mock.frames[#Mock.frames + 1] = frame
	if name then
		Mock.named[name] = frame
	end
	return frame
end

---@param event string
---@param ... any
function Mock.Fire(event, ...)
	for _, frame in ipairs(Mock.eventFrames[event] or {}) do
		local script = frame._scripts.OnEvent
		if script then
			script(frame, event, ...)
		end
	end
end

function Mock.RunTimers()
	local due = Mock.timers
	Mock.timers = {}
	for _, fn in ipairs(due) do
		fn()
	end
end

---@param name string
function Mock.Kill(name)
	Mock.combatLog = { 0, "UNIT_DIED", false, nil, nil, nil, nil, nil, name, 0x440 }
	Mock.Fire("COMBAT_LOG_EVENT_UNFILTERED")
end

---@param opts? { ns?: table, files?: string[] }
---@return table
function Mock.Harness(opts)
	opts = opts or {}
	Mock.Reset()
	local env = setmetatable({
		print = print,
		time = function()
			return Mock.clock
		end,
		date = os.date,
		GetTime = function()
			return Mock.clock
		end,
		GetZoneText = function()
			return Mock.zone
		end,
		GetRealZoneText = function()
			return Mock.zone
		end,
		UnitName = function()
			return "Tester", "TestRealm"
		end,
		GetRealmName = function()
			return "TestRealm"
		end,
		UnitClass = function()
			return "Warrior", "WARRIOR", 1
		end,
		UnitLevel = function()
			return 60
		end,
		UnitGUID = function()
			return "Player-1"
		end,
		InCombatLockdown = function()
			return false
		end,
		GetLocale = function()
			return "enUS"
		end,
		GetBuildInfo = function()
			return "1.15.0", "16001"
		end,
		CombatLogGetCurrentEventInfo = function()
			if Mock.combatLog then
				return unpack(Mock.combatLog)
			end
		end,
		C_Timer = {
			After = function(_, fn)
				Mock.timers[#Mock.timers + 1] = fn
			end,
		},
		CreateColor = function(r, g, b, a)
			return { r = r, g = g, b = b, a = a }
		end,
		geterrorhandler = function()
			return function() end
		end,
		tinsert = table.insert,
		tremove = table.remove,
		wipe = function(value)
			for key in pairs(value) do
				value[key] = nil
			end
		end,
		strtrim = function(value)
			return (tostring(value):gsub("^%s*(.-)%s*$", "%1"))
		end,
		COMBATLOG_OBJECT_REACTION_HOSTILE = 0x00000040,
		COMBATLOG_OBJECT_TYPE_NPC = 0x00000400,
		GameFontNormal = {},
		GameFontHighlight = {},
		GameFontHighlightSmall = {},
		GameFontNormalSmall = {},
		GameFontNormalLarge = {},
		GameFontDisableSmall = {},
		UISpecialFrames = {},
		SlashCmdList = {},
		InterfaceOptions_AddCategory = function() end,
	}, { __index = _G })

	env._G = env
	env.CreateFrame = function(kind, name, parent, template)
		local created = Mock.CreateFrame(kind, name, parent, template)
		if name then
			env[name] = created
		end
		return created
	end
	env.UIParent = env.CreateFrame("Frame", "UIParent")
	env.GameTooltip = env.CreateFrame("Frame", "GameTooltip")

	local ns = opts.ns or {}
	local root = Mock.Root()
	local files = opts.files or Mock.TocFiles()

	local function Load(file)
		local chunk = assert(loadfile(root .. file))
		setfenv(chunk, env)
		return chunk("BestiaryForever", ns)
	end

	for _, file in ipairs(files) do
		Load(file)
	end

	local harness = {
		ns = ns,
		env = env,
		Mock = Mock,
		files = files,
		Load = Load,
	}
	function harness.Fire(_, event, ...)
		Mock.Fire(event, ...)
	end
	function harness.RunTimers(_)
		Mock.RunTimers()
	end
	function harness.Kill(_, name)
		Mock.Kill(name)
	end
	return harness
end

return Mock
