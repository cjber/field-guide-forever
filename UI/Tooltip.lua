---@type string, FGNamespace
local _, ns = ...
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
	tooltip:AddLine(("%s: %s"):format(L["Common"], variants.common.known and known or locked), tr, tg, tb, true)
	if ns.Model.HasRareForm(ns.GetCharacterState(false), species) then
		tooltip:AddLine(
			string.format(L["%s: %s"], L["Rare variant"], variants.rare.known and known or locked),
			tr,
			tg,
			tb,
			true
		)
	end
	tooltip:AddLine(
		string.format(L["%s: %s"], L["Shiny variant"], variants.shiny.known and known or locked),
		tr,
		tg,
		tb,
		true
	)
	tooltip:Show()
end

-- The micro-menu button's tooltip: its title first, the way the shared button drew it, then the binding and what the
-- button opens.
---@param owner Frame
---@param spec FGMicroButtonSpec
function Tooltip.ShowButton(owner, spec)
	local tooltip = Open(owner, "ANCHOR_TOP", spec.title)
	if not tooltip then
		return
	end
	tooltip:AddLine("(" .. spec.binding .. ")", NORMAL_FONT_COLOR:GetRGB())
	tooltip:AddLine(spec.subtext, GRAY_FONT_COLOR:GetRGB())
	tooltip:Show()
end

function Tooltip.Hide()
	if GameTooltip and GameTooltip.Hide then
		-- GameTooltip is shared: the next one to use it gets its own width back.
		GameTooltip:SetMinimumWidth(0)
		GameTooltip:Hide()
	end
end
