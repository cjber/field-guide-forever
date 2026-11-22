---@type string, FGNamespace
local _, ns = ...

if ns.broken then
	return
end

-- luacheck: globals NORMAL_FONT_COLOR GRAY_FONT_COLOR
local L = ns.L
local Art = ns.Art

---@class FGTooltipModule
local Tooltip = {}
ns.Tooltip = Tooltip

-- The client sizes GameTooltip to its widest line, and SetText measures a new title from scratch. A short name such
-- as "Rat" or "Field Guide" would leave everything under it that narrow, so every Field Guide tooltip is given this
-- width after its title is set.
local MIN_WIDTH = 220

-- Starts a tooltip whose lines Field Guide owns. `title` goes through SetText, which resets the measurement, so the
-- minimum width is applied after it; a tooltip built from AddLine alone gets the same width before its first line.
---@param owner Frame
---@param anchor string
---@param title? string
---@return GameTooltip?
local function Open(owner, anchor, title)
	if not GameTooltip or not owner then
		return nil
	end
	GameTooltip:SetOwner(owner, anchor)
	GameTooltip:ClearLines()
	if title then
		GameTooltip:SetText(title)
	end
	GameTooltip:SetMinimumWidth(MIN_WIDTH)
	return GameTooltip
end

---@param owner Frame
---@param entry FGListEntry
function Tooltip.Show(owner, entry)
	local tooltip = Open(owner, "ANCHOR_RIGHT")
	if not tooltip then
		return
	end
	local species = entry.species
	local state = entry.state
	local count = state and state.count or 0
	local r, g, b = Art.RGBA("gold", 1)
	tooltip:AddLine(species.name, r, g, b, true)
	local tr, tg, tb = Art.RGBA("text", 1)
	tooltip:AddLine(string.format(L["%s · %s"], L[species.family], L[species.zone]), tr, tg, tb, true)
	tooltip:AddLine(
		string.format(L["%s · Lv %s"], L[species.family], ns.Model.LevelRange(species.minLevel, species.maxLevel)),
		tr,
		tg,
		tb,
		true
	)
	tooltip:AddLine(string.format(L["Research: %s"], L[ns.Model.RankName(count)]), tr, tg, tb, true)
	local variants = ns.Model.Variants(ns.GetCharacterState(false), species.id)
	local known = L["Known"]
	local locked = L["Locked"]
	for _, tier in ipairs({ "bronze", "silver", "gold", "shiny" }) do
		local label = tier == "shiny" and L["Shiny variant"] or L[tier:sub(1, 1):upper() .. tier:sub(2)]
		tooltip:AddLine(string.format(L["%s: %s"], label, variants[tier].known and known or locked), tr, tg, tb, true)
	end
	tooltip:Show()
end

function Tooltip.Hide()
	if GameTooltip and GameTooltip.Hide then
		-- GameTooltip is shared: the next one to use it gets its own width back.
		GameTooltip:SetMinimumWidth(0)
		GameTooltip:Hide()
	end
end

-- The unit's GUID: the tooltip data's own, else the GUID of the unit the tooltip shows. Either may be secret.
---@param tooltip GameTooltip
---@param data? TooltipData
---@return string?
local function UnitGuid(tooltip, data)
	local guid = type(data) == "table" and ns.Readable(data.guid) or nil
	if guid then
		return guid
	end
	if tooltip.GetUnit then
		local unit = ns.Readable((select(2, tooltip:GetUnit())))
		if unit and UnitGUID then
			return ns.Readable(UnitGUID(unit))
		end
	end
	return nil
end

-- World unit tooltip lines: a catalogued creature shows Field Guide's research rank and kill count, or notes that it
-- is not yet in the journal. Runs out of combat with one saved-state lookup and touches no secure frames.
---@param tooltip GameTooltip
---@param data? TooltipData
local function OnUnitTooltip(tooltip, data)
	if not ns.ready or (InCombatLockdown and InCombatLockdown()) then
		return
	end
	if ns.db and ns.db.options and ns.db.options.creatureTooltips == false then
		return
	end
	local state = ns.GetCharacterState(false)
	if not state then
		return
	end
	local npcId = ns.NpcId(UnitGuid(tooltip, data))
	if not npcId or not (ns.SpeciesById and ns.SpeciesById[npcId]) then
		return
	end
	local entry = state.species and state.species[npcId]
	local count = entry and entry.count or 0
	GameTooltip_AddNormalLine(tooltip, L["Field Guide"])
	if count > 0 then
		local kills = (entry and entry.kills) or count
		local rankText = string.format(L["Research: %s"], L[ns.Model.RankName(count)])
		local killText = string.format(kills == 1 and L["%d kill"] or L["%d kills"], kills)
		GameTooltip_AddHighlightLine(tooltip, string.format(L["%s · %s"], rankText, killText))
	else
		GameTooltip_AddDisabledLine(tooltip, L["Not yet in your journal"])
	end
end

-- A forbidden tooltip is never read or drawn on, and a unit or GUID the client keeps secret reads as no unit: the hover
-- shows nothing of ours rather than raising an error.
if
	TooltipDataProcessor
	and TooltipDataProcessor.AddTooltipPostCall
	and Enum
	and Enum.TooltipDataType
	and Enum.TooltipDataType.Unit
then
	---@param tooltip GameTooltip
	---@param data? TooltipData
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
		if not ns.Usable(tooltip) then
			return
		end
		ns.core.SafeCall("unit tooltip", OnUnitTooltip, tooltip, data)
	end)
end
