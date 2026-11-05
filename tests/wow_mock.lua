-- A headless client good enough for the specs: frames are inert tables and events are delivered by hand. Units are what
-- the spec placed in Mock.units (names), Mock.guids, Mock.dead and Mock.tapDenied; map markers are Mock.vignettes. Like
-- Forever, the client has no addon reader for the combat log unless a harness asks for one ({ combatLog = true }), and
-- then it returns Mock.combatLog. Nothing here is loaded by the addon.

local Mock = {}

Mock.zone = "The Barrens"
Mock.clock = 1000
Mock.frames = {}
Mock.eventFrames = {}
Mock.named = {}
Mock.timers = {}
Mock.combatLog = nil
Mock.units = {}
Mock.guids = {}
Mock.dead = {}
Mock.tapDenied = {}
Mock.vignettes = {}
Mock.spawnCounter = 0
Mock.refusedEvents = {}
Mock.inGuild = false
Mock.inGroup = false
Mock.inRaid = false
Mock.sentAddonMessages = {}
Mock.registeredPrefix = nil
Mock.instanceGroup = false

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
		if exists(prefix .. "FieldGuideForever.toc") then
			return prefix
		end
	end
	return ""
end

---@return string[]
function Mock.TocFiles()
	local files = {}
	local file = io.open(Mock.Root() .. "FieldGuideForever.toc", "r")
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
	Mock.openedMap = nil
	Mock.zone = "The Barrens"
	Mock.clock = 1000
	Mock.frames = {}
	Mock.eventFrames = {}
	Mock.named = {}
	Mock.timers = {}
	Mock.combatLog = nil
	Mock.units = {}
	Mock.guids = {}
	Mock.dead = {}
	Mock.tapDenied = {}
	Mock.vignettes = {}
	Mock.spawnCounter = 0
	Mock.inGuild = false
	Mock.inGroup = false
	Mock.inRaid = false
	Mock.sentAddonMessages = {}
	Mock.registeredPrefix = nil
	Mock.instanceGroup = false
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
		_vertexColor = { 1, 1, 1, 1 },
		_desaturated = false,
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

function methods:SetCreature(id)
	self.creatureID = id
	self.creatureLoads = (rawget(self, "creatureLoads") or 0) + 1
end

function methods:ClearModel()
	self.modelFileID = nil
	self.creatureID = nil
end

function methods:GetModelFileID()
	return rawget(self, "modelFileID")
end

function methods:SetAtlas(atlas)
	self.atlas = atlas
end

function methods:GetAtlas()
	return rawget(self, "atlas")
end

function methods:SetShadowColor(r, g, b, a)
	self.shadowColor = { r, g, b, a }
end

-- An animation group plays until stopped; its animations only record what they were given.
function methods:CreateAnimationGroup()
	local group = NewRegion("AnimationGroup", nil, self)
	group.animations = {}
	group.playing = false
	function group.Play(selfGroup)
		selfGroup.playing = true
	end
	function group.Stop(selfGroup)
		selfGroup.playing = false
	end
	function group.IsPlaying(selfGroup)
		return selfGroup.playing
	end
	function group.SetLooping(selfGroup, looping)
		selfGroup.looping = looping
	end
	function group.CreateAnimation(selfGroup, kind)
		local animation = NewRegion(kind, nil, selfGroup)
		selfGroup.animations[#selfGroup.animations + 1] = animation
		return animation
	end
	return group
end

function methods:GetScript(event)
	return self._scripts[event]
end

function methods:HookScript(event, fn)
	local original = self._scripts[event]
	if not original then
		self._scripts[event] = fn
		return
	end
	self._scripts[event] = function(...)
		original(...)
		fn(...)
	end
end

function methods:RegisterEvent(event)
	if Mock.refusedEvents[event] then
		error("Attempt to register for a restricted event: " .. event)
	end
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

function methods:SetNormalAtlas(atlas)
	self.normalAtlas = atlas
end

function methods:SetPushedAtlas(atlas)
	self.pushedAtlas = atlas
end

function methods:SetDisabledAtlas(atlas)
	self.disabledAtlas = atlas
end

function methods:SetHighlightAtlas(atlas)
	self.highlightAtlas = atlas
end

function methods.Layout() end

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

function methods.SetBlendMode() end

function methods.SetFromAlpha() end

function methods.SetToAlpha() end

function methods.SetDuration() end

function methods.SetOrder() end

function methods.SetSmoothing() end

function methods.SetStartDelay() end

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

function methods:SetTextColor(r, g, b, a)
	self._textColor = { r, g, b, a or 1 }
end

function methods:GetTextColor()
	return unpack(self._textColor or { 1, 1, 1, 1 })
end

function methods:SetVertexColor(r, g, b, a)
	self._vertexColor = { r, g, b, a }
end

function methods:SetStatusBarColor(r, g, b, a)
	self._statusBarColor = { r, g, b, a or 1 }
end

function methods:GetStatusBarColor()
	return unpack(self._statusBarColor or { 1, 1, 1, 1 })
end

function methods:GetVertexColor()
	return unpack(self._vertexColor)
end

function methods:SetTexture(texture)
	self._texture = texture
end

function methods.SetTexCoord() end

function methods:SetDesaturated(value)
	self._desaturated = value and true or false
end

function methods:IsDesaturated()
	return self._desaturated
end

function methods.SetDrawLayer() end

function methods.SetHitRectInsets() end

function methods:SetScrollChild(child)
	self._scrollChild = child
end

function methods:SetVerticalScroll(value)
	self.verticalScroll = value
end

function methods:GetVerticalScroll()
	return rawget(self, "verticalScroll") or 0
end

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

function methods:GetFontString()
	local label = rawget(self, "_fontString") or NewRegion("FontString", nil, self)
	self._fontString = label
	return label
end

function methods.ClearFocus() end

function methods.SetFocus() end

function methods:SetParent(parent)
	self._parent = parent
end

-- A frame's methods are all in `methods`; anything else a client frame answers with nil when it has not been set.
-- The fields named here are data a frame carries (Forever Core's settings page keeps its row cursor in one), so they
-- must read nil until something writes them, exactly as on the client, and never the no-op the fallback returns.
local DATA_FIELDS = {
	settingsRowY = true,
	creatureID = true,
	modelFileID = true,
	id = true,
	atlas = true,
	shadowColor = true,
	FlashBorder = true,
	fgfToast = true,
	fgfHooked = true,
}
setmetatable(methods, {
	__index = function(_, key)
		if DATA_FIELDS[key] then
			return nil
		end
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

-- A fresh creature GUID, as the client builds one: the NPC id is the sixth field and the spawn the seventh.
---@param npcId integer?
---@return string
function Mock.CreatureGUID(npcId)
	Mock.spawnCounter = Mock.spawnCounter + 1
	return string.format("Creature-0-1-0-1-%d-%010X", npcId or 0, Mock.spawnCounter)
end

-- The player's target dies, the way Forever reports it to an addon: its health event, with UnitIsDead now true.
---@param name string
---@param npcId integer?
function Mock.Kill(name, npcId)
	Mock.units.target = name
	Mock.guids.target = Mock.CreatureGUID(npcId)
	Mock.dead.target = true
	Mock.tapDenied.target = nil
	Mock.Fire("UNIT_HEALTH", "target")
end

-- `combatLog` gives the client an addon reader for the combat log; `refuse` names events whose registration raises.
---@param opts? { ns?: table, files?: string[], combatLog?: boolean, refuse?: table<string, boolean> }
---@return table
function Mock.Harness(opts)
	opts = opts or {}
	Mock.Reset()
	Mock.refusedEvents = opts.refuse or {}
	local env = setmetatable({
		print = print,
		time = function()
			return Mock.clock
		end,
		date = os.date,
		GetTime = function()
			return Mock.clock
		end,
		GetServerTime = function()
			return Mock.clock
		end,
		GetZoneText = function()
			return Mock.zone
		end,
		GetRealZoneText = function()
			return Mock.zone
		end,
		UnitName = function(unit)
			return Mock.units[unit] or "Tester", "TestRealm"
		end,
		UnitIsEnemy = function()
			return true
		end,
		UnitIsPlayer = function()
			return false
		end,
		UnitIsDead = function(unit)
			return Mock.dead[unit] == true
		end,
		UnitCanAttack = function()
			return true
		end,
		UnitIsTapDenied = function(unit)
			return Mock.tapDenied[unit] == true
		end,
		C_VignetteInfo = {
			GetVignettes = function()
				local guids = {}
				for index, vignette in ipairs(Mock.vignettes) do
					guids[index] = vignette.vignetteGUID
				end
				return guids
			end,
			GetVignetteInfo = function(vignetteGUID)
				for _, vignette in ipairs(Mock.vignettes) do
					if vignette.vignetteGUID == vignetteGUID then
						return vignette
					end
				end
			end,
		},
		GetInstanceInfo = function()
			return "Test Instance"
		end,
		GetDifficultyInfo = function()
			return "Normal"
		end,
		IsInGuild = function()
			return Mock.inGuild
		end,
		IsInGroup = function(category)
			if category then
				return Mock.instanceGroup
			end
			return Mock.inGroup or Mock.inRaid
		end,
		IsInRaid = function()
			return Mock.inRaid
		end,
		LE_PARTY_CATEGORY_INSTANCE = 1,
		Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8 } },
		C_ChatInfo = {
			RegisterAddonMessagePrefix = function(prefix)
				Mock.registeredPrefix = prefix
			end,
			SendAddonMessage = function(prefix, message, channel)
				Mock.sentAddonMessages[#Mock.sentAddonMessages + 1] = {
					prefix = prefix,
					message = message,
					channel = channel,
				}
				return true
			end,
		},
		GetRealmName = function()
			return "TestRealm"
		end,
		UnitClass = function()
			return "Warrior", "WARRIOR", 1
		end,
		UnitLevel = function()
			return 60
		end,
		UnitGUID = function(unit)
			return Mock.guids[unit] or "Player-1"
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
		C_Timer = {
			After = function(_, fn)
				Mock.timers[#Mock.timers + 1] = fn
			end,
		},
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
		UIPanelWindows = {},
		SlashCmdList = {},
		InterfaceOptions_AddCategory = function() end,
		-- The modern settings API, as Interface 16001 offers it: one canvas category registered by name.
		Settings = {
			RegisterCanvasLayoutCategory = function(panel, name)
				return { panel = panel, name = name }
			end,
			RegisterAddOnCategory = function() end,
		},
	}, { __index = _G })
	env._G = env
	if opts.combatLog then
		env.CombatLogGetCurrentEventInfo = function()
			if Mock.combatLog then
				return unpack(Mock.combatLog)
			end
		end
	end
	env.ForeverPeerStats = false
	env.CreateFrame = function(kind, name, parent, template)
		local created = Mock.CreateFrame(kind, name, parent, template)
		created.template = template
		if template == "LargeSideTabButtonTemplate" then
			created.Icon = NewRegion("Texture", nil, created)
			created.SelectedTexture = NewRegion("Texture", nil, created)
			created.SetFillToInterior = function() end
			created.SetCustomOnMouseUpHandler = function(self, handler)
				self.customOnMouseUpHandler = handler
			end
		end
		if template == "AchievementAlertFrameTemplate" then
			-- Mainline/AlertFrameSystems.xml:173-327: the regions the toast's set-up reaches for.
			created.Background = NewRegion("Texture", nil, created)
			created.Unlocked = NewRegion("FontString", nil, created)
			created.Unlocked:SetText("Achievement Unlocked")
			created.Name = NewRegion("FontString", nil, created)
			created.GuildName = NewRegion("FontString", nil, created)
			created.GuildBanner = NewRegion("Texture", nil, created)
			created.GuildBorder = NewRegion("Texture", nil, created)
			created.glow = NewRegion("Texture", nil, created)
			created.shine = NewRegion("Texture", nil, created)
			created.Icon = NewRegion("Frame", nil, created)
			created.Icon.Texture = NewRegion("Texture", nil, created.Icon)
			created.Icon.Overlay = NewRegion("Texture", nil, created.Icon)
			created.Shield = NewRegion("Frame", nil, created)
		end
		if template and template:find("PortraitFrameTemplate", 1, true) then
			created.PortraitContainer = { portrait = NewRegion("Texture", nil, created) }
			created.TitleContainer = { TitleText = NewRegion("FontString", nil, created) }
			created.CloseButton = Mock.CreateFrame("Button", nil, created, "UIPanelCloseButton")
		end
		if template == "MainMenuBarMicroButton" then
			created.FlashBorder = NewRegion("Texture", nil, created)
			created.FlashBorder:Hide()
			created.alert = {
				Hide = function(self)
					self.hidden = true
				end,
			}
		end
		if name then
			env[name] = created
		end
		return created
	end
	env.PanelTemplates_SelectTab = function(button)
		button.selected = true
	end
	env.PanelTemplates_DeselectTab = function(button)
		button.selected = false
	end
	env.PanelTemplates_TabResize = function(button, _padding, width)
		button:SetSize(width, 32)
	end
	env.C_Map = {
		OpenWorldMap = function(id)
			Mock.openedMap = id
		end,
	}
	env.UIParent = env.CreateFrame("Frame", "UIParent")
	-- The panel manager as an addon sees it: it refuses addon calls in combat, and a registered panel is shown or
	-- hidden by the manager, which remembers it in a slot.
	Mock.panelCalls = {}
	env.ShowUIPanel = function(panel)
		Mock.panelCalls[#Mock.panelCalls + 1] = "show"
		if env.InCombatLockdown() then
			Mock.blocked = (Mock.blocked or 0) + 1
			return
		end
		Mock.panelSlot = env.UIPanelWindows[panel:GetName()] and panel or nil
		panel:Show()
	end
	env.HideUIPanel = function(panel)
		Mock.panelCalls[#Mock.panelCalls + 1] = "hide"
		if env.InCombatLockdown() then
			Mock.blocked = (Mock.blocked or 0) + 1
			return
		end
		Mock.panelSlot = nil
		panel:Hide()
	end
	-- Escape: the manager closes its panels, then every special frame that is shown.
	env.CloseAllWindows = function()
		local found = false
		if Mock.panelSlot and Mock.panelSlot:IsShown() then
			Mock.panelSlot:Hide()
			Mock.panelSlot, found = nil, true
		end
		for _, name in ipairs(env.UISpecialFrames) do
			local special = env[name]
			if special and special:IsShown() then
				special:Hide()
				found = true
			end
		end
		return found
	end
	env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
	env.GameTooltip = env.CreateFrame("Frame", "GameTooltip")
	env.GameTooltip.SetOwner = function() end
	env.GameTooltip.SetText = function() end
	env.GameTooltip.AddLine = function() end
	env.GameTooltip.Show = function() end
	env.GameTooltip_Hide = function() end
	env.NORMAL_FONT_COLOR = {
		GetRGB = function()
			return 1, 0.82, 0
		end,
	}
	env.GRAY_FONT_COLOR = {
		GetRGB = function()
			return 0.5, 0.5, 0.5
		end,
	}
	env.MicroMenu = env.CreateFrame("Frame", "MicroMenu")
	env.MicroMenu.childXPadding, env.MicroMenu.isHorizontal, env.MicroMenu.layoutFramesGoingRight = -5, true, true
	env.MicroMenu.stride = 12
	env.MainMenuMicroButton = env.CreateFrame("Button", "MainMenuMicroButton", env.MicroMenu)
	env.CollectionsMicroButton = env.CreateFrame("Button", "CollectionsMicroButton", env.MicroMenu)
	env.AdventureGuideMicroButton = env.CreateFrame("Button", "AdventureGuideMicroButton", env.MicroMenu)
	env.UpdateMicroButtons = function() end
	-- hooksecurefunc([table,] name, callback): the hook runs after the original and its return is ignored.
	env.hooksecurefunc = function(target, name, callback)
		if callback == nil then
			target, name, callback = env, target, name
		end
		local original = target[name]
		target[name] = function(...)
			local result = { original(...) }
			callback(...)
			return unpack(result)
		end
	end
	env.SOUNDKIT = {
		IG_ABILITY_PAGE_TURN = 836,
		UI_EPICLOOT_TOAST = 31578,
		UI_LEGENDARY_LOOT_TOAST = 63971,
		UI_RAID_LOOT_TOAST_LESSER_ITEM_WON = 31579,
	}
	Mock.sounds = {}
	env.PlaySound = function(kit)
		Mock.sounds[#Mock.sounds + 1] = kit
	end
	-- Blizzard_UIErrorsFrame: Mock.messages holds every line added, with its colour.
	Mock.messages = {}
	env.UIErrorsFrame = {
		AddMessage = function(_, text, r, g, b)
			Mock.messages[#Mock.messages + 1] = { text = text, r = r, g = g, b = b }
		end,
	}
	env.NEW_FEATURE_SHADOW_COLOR = {
		GetRGBA = function()
			return 0.32, 0.5, 1, 1
		end,
	}
	-- Mainline/AlertFrames.lua:91-256: a queued subsystem shows up to maxAlerts toasts of its template, each from its
	-- own pool and filled by its setUp, and queues up to maxQueue more; a toast's hide frees its place for the next.
	-- Mock.alerts holds every toast shown, in order. AlertFrame_OnClick dismisses on a right click.
	Mock.alerts = {}
	env.AlertFrame = env.CreateFrame("Frame", "AlertFrame", env.UIParent)
	function env.AlertFrame.AddQueuedAlertFrameSubSystem(_, template, setUp, maxAlerts, maxQueue)
		local system, free, shown, queued = {}, {}, 0, {}
		local function Show(...)
			local frame = table.remove(free)
			if not frame then
				frame = env.CreateFrame("Button", nil, env.UIParent, template)
				frame:SetScript("OnClick", function(self, button)
					if button == "RightButton" then
						self:Hide()
					end
				end)
				local hide = frame.Hide
				frame.Hide = function(self)
					hide(self)
					shown = shown - 1
					free[#free + 1] = self
					local waiting = table.remove(queued, 1)
					if waiting then
						Show(unpack(waiting, 1, waiting.n))
					end
				end
			end
			setUp(frame, ...)
			shown = shown + 1
			Mock.alerts[#Mock.alerts + 1] = frame
			frame:Show()
		end
		function system.AddAlert(_, ...)
			if shown < (maxAlerts or 2) then
				Show(...)
			elseif #queued < (maxQueue or 6) then
				queued[#queued + 1] = { n = select("#", ...), ... }
			else
				return false
			end
			return true
		end
		return system
	end
	env.AchievementAlertSystem = {}

	local ns = opts.ns or {}
	local root = Mock.Root()
	local files = opts.files or Mock.TocFiles()

	local function Load(file)
		local chunk = assert(loadfile(root .. file))
		setfenv(chunk, env)
		return chunk("FieldGuideForever", ns)
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
	function harness.Kill(_, name, npcId)
		Mock.Kill(name, npcId)
	end
	return harness
end

return Mock
