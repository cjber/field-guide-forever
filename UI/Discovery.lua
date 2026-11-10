---@type string, FGNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L

-- What a kill shows. A first kill is announced the way the client announces an explored area: one yellow line in
-- UIErrorsFrame, with the page-turn sound, a New tag in the journal and the minimap button pulsing until the journal
-- opens. The big moments (a rare's first kill, a shiny, a mastered species, a zone with every creature recorded) take
-- the client's own achievement toast (Mainline/AlertFrameSystems.xml:173), queued through AlertFrame as achievements
-- are: two on screen, six waiting.
--
-- Core calls in from the kill handler, which can run in combat, so a record is only noted here and everything shown
-- waits for the next frame. Nothing here touches a secure frame: the toasts come from this addon's own AlertFrame
-- pool and the pulse animates the minimap button this addon owns.
---@class FGDiscovery
---@field pulseGlow? Texture the minimap button's glow while it pulses
local Discovery = {}
ns.Discovery = Discovery

local TEMPLATE = "AchievementAlertFrameTemplate"
local ACHIEVEMENT_SOUND = 12891 -- the achievement-gained chime; not in SOUNDKIT
-- At most this many toasts from one burst of kills; the rest of a big pull is left to the journal.
Discovery.BURST_TOASTS = 3
-- A burst names this many new creatures and counts the rest.
local NAMED_IN_LINE = 2

-- Biggest first: one kill shows only its biggest milestone, and a capped burst keeps the biggest ones.
local PRIORITY = { shiny = 1, gold = 2, silver = 3, zone = 4, mastered = 5 }

local HEADINGS = {
	shiny = "Shiny found",
	gold = "Gold found",
	silver = "Silver found",
	mastered = "Mastered",
	zone = "Zone complete",
}

---@class FGToast
---@field kind string
---@field name string
---@field icon string
---@field speciesId? integer
---@field zone? FGZone

---@class FGToastFrame : Button
---@field Background Texture
---@field Unlocked FontString
---@field Name FontString
---@field GuildName FontString
---@field GuildBanner Texture
---@field GuildBorder Texture
---@field Icon Frame|{Texture: Texture, Overlay: Texture}
---@field Shield Frame
---@field glow Texture
---@field shine Texture
---@field id integer?
---@field fgfToast FGToast?
---@field fgfHooked boolean?

---@type { species: FGSpecies, zone: FGZone, result: FGRecordResult }[]
local pending = {}
local flushScheduled = false

---@return FGOptions
local function Options()
	return ns.db and ns.db.options or {}
end

local function Sound(kit)
	if PlaySound and SOUNDKIT and SOUNDKIT[kit] then
		PlaySound(SOUNDKIT[kit])
	end
end

---@param speciesId integer?
---@param zone FGZone?
function Discovery.Open(speciesId, zone)
	local window = ns.Window
	if not window then
		return
	end
	zone = zone or (speciesId and ns.SpeciesZone[speciesId])
	window.Show()
	window.SetTab("creatures")
	for index, entry in ipairs(ns.Zones or {}) do
		if entry == zone then
			window.SelectZone(index)
			break
		end
	end
	if speciesId then
		window.SelectSpecies(speciesId)
	end
end

-- AlertFrame_OnClick has already dismissed the toast on a right click; a left click opens what it names.
---@param frame FGToastFrame
---@param button string
local function OnClick(frame, button)
	local toast = frame.fgfToast
	if button == "LeftButton" and toast then
		ns.core.SafeCall("discovery toast", Discovery.Open, toast.speciesId, toast.zone)
	end
end

-- AchievementAlertFrame_SetUp's two branches, reset on every use because the pool hands frames back in any state:
-- the shiny takes the guild branch's art (its larger frame) without the guild's name and banner, the rest the
-- standard art. The shield's points hide and the heading centres, as for an achievement already earned. The glow and
-- shine layers stay hidden: the heading names the milestone instead.
---@param frame FGToastFrame
---@param guild boolean
local function SetArt(frame, guild)
	frame.Shield:Hide()
	frame.GuildName:Hide()
	frame.GuildBanner:Hide()
	frame.GuildBorder:Hide()
	frame.Background:SetAtlas(guild and "ui-achievement-guild-background" or "ui-achievement-alert-background", true)
	frame.Icon.Overlay:SetAtlas(guild and "ui-achievement-guild-iconframe" or "ui-achievement-iconframe", true)
	frame.glow:Hide()
	frame.shine:Hide()
	frame:SetHeight(guild and 104 or 101)
	frame.Icon.Overlay:ClearAllPoints()
	frame.Icon.Overlay:SetPoint("CENTER", guild and 0 or -1, guild and 0 or 1)
	frame.Icon:ClearAllPoints()
	frame.Icon:SetPoint("TOPLEFT", guild and 0 or -4, guild and -25 or -15)
	frame.Icon.Texture:ClearAllPoints()
	frame.Icon.Texture:SetPoint("CENTER", guild and -1 or 0, guild and -2 or 0)
	frame.Unlocked:ClearAllPoints()
	frame.Unlocked:SetPoint("TOP", guild and 0 or 27, guild and -38 or -23)
end

---@param frame FGToastFrame
---@param toast FGToast
local function SetUp(frame, toast)
	frame.id = nil
	frame.fgfToast = toast
	if not frame.fgfHooked then
		frame:HookScript("OnClick", OnClick)
		frame.fgfHooked = true
	end
	SetArt(frame, toast.kind == "shiny")
	frame.Unlocked:SetText(L[HEADINGS[toast.kind]])
	frame.Name:SetText(toast.name)
	frame.Icon.Texture:SetTexture(toast.icon)
	if PlaySound then
		PlaySound(ACHIEVEMENT_SOUND)
	end
end

-- AlertFrames.lua:544 loads the achievement UI before its own toasts: AchievementAlertFrameTemplate's Shield child
-- calls AchievementShield_OnLoad from the load-on-demand Blizzard_AchievementUI, so a toast built without it warns.
local function LoadAchievementUI()
	if AchievementFrame_LoadUI then
		AchievementFrame_LoadUI()
	elseif C_AddOns and C_AddOns.LoadAddOn then
		C_AddOns.LoadAddOn("Blizzard_AchievementUI")
	end
end

---@type table?
local system
-- Registered at the first milestone, so a session without one adds nothing to AlertFrame. The achievement system's
-- own global stands for its template being loaded.
local function System()
	if not system and AlertFrame and AchievementAlertSystem then
		LoadAchievementUI()
		system = AlertFrame:AddQueuedAlertFrameSubSystem(TEMPLATE, SetUp, 2, 6)
	end
	return system
end

---@param zone FGZone
---@return boolean
local function ZoneComplete(zone)
	local progress = ns.Model.ZoneProgress(ns.GetCharacterState(false), zone.species)
	return progress.total > 0 and progress.catalogued == progress.total
end

---@param result FGRecordResult
---@return string?
local function SpeciesMilestone(result)
	if result.firstShiny then
		return "shiny"
	elseif result.firstGold then
		return "gold"
	elseif result.firstSilver then
		return "silver"
	elseif result.rank == 4 and result.previousRank < 4 then
		return "mastered"
	end
	return nil
end

---@param species FGSpecies
---@param kind string
---@return FGToast
local function SpeciesToast(species, kind)
	local name = species.name
	if kind == "shiny" then
		name = string.format(L["Shiny %s!"], species.name)
	end
	return { kind = kind, name = name, icon = ns.Art.SpeciesIcon(species.name, species.id), speciesId = species.id }
end

---@param names string[]
---@return string
local function DiscoveryLine(names)
	if #names == 1 then
		return string.format(L["New creature recorded: %s"], names[1])
	end
	local shown = {}
	for index = 1, math.min(#names, NAMED_IN_LINE) do
		shown[index] = names[index]
	end
	local line = string.format(L["New creatures recorded: %s"], table.concat(shown, L[", "]))
	if #names > NAMED_IN_LINE then
		line = string.format(L["%s and %d more"], line, #names - NAMED_IN_LINE)
	end
	return line
end

-- The minimap button's own round glow, pulsed with the timing MicroButtonPulse gave UIFrameFlash (one second in, one
-- out). The animation keeps the pulse on the button this addon owns rather than writing it into Blizzard's table of
-- flashing buttons.
---@return Texture?
local function PulseGlow()
	local button = ns.minimapButton
	if not button then
		return nil
	end
	if not Discovery.pulseGlow then
		local glow = button:CreateTexture(nil, "OVERLAY")
		glow:SetAtlas("bags-roundhighlight") -- art-ok: the client's own round hover glow
		glow:SetAllPoints(button)
		glow:SetBlendMode("ADD")
		glow:Hide()
		Discovery.pulseGlow = glow
	end
	return Discovery.pulseGlow
end

function Discovery.StartPulse()
	local border = PulseGlow()
	if not border or not border.CreateAnimationGroup then
		return
	end
	if not Discovery.pulse then
		local pulse = border:CreateAnimationGroup()
		pulse:SetLooping("REPEAT")
		local fadeIn = pulse:CreateAnimation("Alpha")
		fadeIn:SetFromAlpha(0)
		fadeIn:SetToAlpha(1)
		fadeIn:SetDuration(1)
		fadeIn:SetOrder(1)
		local fadeOut = pulse:CreateAnimation("Alpha")
		fadeOut:SetFromAlpha(1)
		fadeOut:SetToAlpha(0)
		fadeOut:SetDuration(1)
		fadeOut:SetOrder(2)
		Discovery.pulse = pulse
	end
	border:Show()
	Discovery.pulse:Play()
end

function Discovery.StopPulse()
	if Discovery.pulse then
		Discovery.pulse:Stop()
	end
	if Discovery.pulseGlow then
		Discovery.pulseGlow:Hide()
	end
end

local function Flush()
	flushScheduled = false
	local records = pending
	pending = {}
	local options = Options()
	local toastsOn = options.milestoneToasts ~= false
	---@type FGToast[]
	local toasts = {}
	local names = {}
	local discovered = false
	---@type table<FGZone, true>
	local zonesDone = {}
	for _, record in ipairs(records) do
		local species, zone, result = record.species, record.zone, record.result
		local kind = SpeciesMilestone(result)
		if kind then
			toasts[#toasts + 1] = SpeciesToast(species, kind)
		end
		if result.newlyDiscovered then
			discovered = true
			-- A first kill that earns a toast is told by the toast; the line is for the rest.
			if not (kind and toastsOn) then
				names[#names + 1] = species.name
			end
			if not zonesDone[zone] and ZoneComplete(zone) then
				zonesDone[zone] = true
				toasts[#toasts + 1] = {
					kind = "zone",
					name = string.format(L["%s: every creature recorded"], L[zone.name]),
					icon = ns.icon,
					zone = zone,
				}
			end
		end
	end
	if discovered then
		Discovery.StartPulse()
	end
	if #names > 0 and options.discoveryText ~= false and UIErrorsFrame then
		UIErrorsFrame:AddMessage(DiscoveryLine(names), 1, 1, 0, 1)
		Sound("IG_ABILITY_PAGE_TURN")
	end
	if #toasts == 0 or not toastsOn then
		return
	end
	table.sort(toasts, function(a, b)
		return PRIORITY[a.kind] < PRIORITY[b.kind]
	end)
	local alerts = System()
	for index = 1, math.min(#toasts, Discovery.BURST_TOASTS) do
		if alerts then
			alerts:AddAlert(toasts[index])
		end
	end
end

ns.OnRecord(function(species, zone, result)
	pending[#pending + 1] = { species = species, zone = zone, result = result }
	if not flushScheduled then
		flushScheduled = true
		C_Timer.After(0, function()
			ns.core.SafeCall("discovery", Flush)
		end)
	end
end)

-- The journal showing a species is the player having seen it: its New tag goes, and opening the journal stops the
-- micro button's pulse, as opening the collections journal does.
hooksecurefunc(ns.Detail, "Show", function(species)
	local state = species and ns.GetCharacterState(false)
	if state and state.unseen and state.unseen[species.id] then
		state.unseen[species.id] = nil
		ns.List.ClearNew(species.id)
	end
end)
hooksecurefunc(ns.Window, "Show", Discovery.StopPulse)
