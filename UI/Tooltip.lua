---@type string, FGNamespace
local _, ns = ...
local L = ns.L
local Art = ns.Art

---@class FGTooltipModule
local Tooltip = {}
ns.Tooltip = Tooltip

-- Every line wraps, so a short creature name would size the whole tooltip to itself and wrap the facts under it.
local MIN_WIDTH = 220

---@param owner Frame
---@param entry FGListEntry
function Tooltip.Show(owner, entry)
	if not GameTooltip or not owner then
		return
	end
	local species = entry.species
	local state = entry.state
	local count = state and state.count or 0
	local r, g, b = Art.RGBA("gold", 1)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:SetMinimumWidth(MIN_WIDTH)
	GameTooltip:AddLine(species.name, r, g, b, true)
	local tr, tg, tb = Art.RGBA("text", 1)
	GameTooltip:AddLine(string.format(L["%s · %s"], L[species.family], L[species.zone]), tr, tg, tb, true)
	GameTooltip:AddLine(
		string.format(L["%s · Lv %s"], L[species.family], ns.Model.LevelRange(species.minLevel, species.maxLevel)),
		tr,
		tg,
		tb,
		true
	)
	GameTooltip:AddLine(string.format(L["Research: %s"], L[ns.Model.RankName(count)]), tr, tg, tb, true)
	local variants = ns.Model.Variants(ns.GetCharacterState(false), species.id)
	local known = L["Known"]
	local locked = L["Locked"]
	GameTooltip:AddLine(("%s: %s"):format(L["Common"], variants.common.known and known or locked), tr, tg, tb, true)
	if ns.Model.HasRareForm(ns.GetCharacterState(false), species) then
		GameTooltip:AddLine(
			string.format(L["%s: %s"], L["Rare variant"], variants.rare.known and known or locked),
			tr,
			tg,
			tb,
			true
		)
	end
	GameTooltip:AddLine(
		string.format(L["%s: %s"], L["Shiny variant"], variants.shiny.known and known or locked),
		tr,
		tg,
		tb,
		true
	)
	GameTooltip:Show()
end

function Tooltip.Hide()
	if GameTooltip and GameTooltip.Hide then
		-- GameTooltip is shared: the next one to use it gets its own width back.
		GameTooltip:SetMinimumWidth(0)
		GameTooltip:Hide()
	end
end
