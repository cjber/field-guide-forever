-- The detail header breathes: the name and subtitle do not touch, the subtitle keeps clear of the variant cards,
-- and a two-line card status stays off the card's bottom edge.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local detail = harness.ns.Detail
detail.Create(harness.env.CreateFrame("Frame"))

local function Top(widget)
	local _, _, _, _, y = widget:GetPoint(1)
	return y
end

local nameY = Top(detail.name)
local nameHeight = detail.name:GetHeight()
local subtitleY = Top(detail.sub)
local subtitleHeight = detail.sub:GetHeight()
local cardY = Top(detail.cards.common)
local cardHeight = detail.cards.common:GetHeight()
local titleY = Top(detail.cards.common.Title)
local statusY = Top(detail.cards.common.Status)

local nameGap = nameY - nameHeight - subtitleY
assert(nameGap >= 6, "name and subtitle need space between them: " .. nameGap)
local headerGap = subtitleY - subtitleHeight - cardY
assert(headerGap >= 16, "subtitle keeps clear of the portrait cards: " .. headerGap)
assert(titleY - statusY >= 24, "the card title sits above its status text")
-- A status line is 14 units in the client's small font; two lines must leave a real margin inside the card.
local statusBottom = -statusY + 28
assert(statusBottom <= cardHeight - 24, "two status lines stay off the card's bottom edge: " .. statusBottom)
print("detail layout: ok")
