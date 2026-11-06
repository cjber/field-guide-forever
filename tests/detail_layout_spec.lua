-- The detail pane reads top to bottom without collisions: name over subtitle beside the portrait, the variants
-- heading below the card, its slots below the heading, each slot's status inside it, then records and habitat, with
-- the habitat map and its button inside the pane.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local detail = harness.ns.Detail
detail.Create(harness.env.CreateFrame("Frame"))

-- The mock keeps SetPoint's short form (point, x, y) as given.
local function Point(widget)
	local _, a, b, x, y = widget:GetPoint(1)
	if type(a) == "number" then
		return a, b
	end
	return x, y
end

local nameX, nameY = Point(detail.name)
local _, subtitleY = Point(detail.sub)
local portraitX, portraitY = Point(detail.portrait)
local cardDividerY = -160
local _, variantsY = Point(detail.variantsBand)
local _, slotY = Point(detail.slots.bronze)
local slotHeight = detail.slots.bronze:GetHeight()
local _, cardTitleY = Point(detail.slots.bronze.Title)
local _, cardStatusY = Point(detail.slots.bronze.Status)
local _, recordsY = Point(detail.recordsBand)
local _, habitatY = Point(detail.habitatBand)
local _, locationY = Point(detail.location)
local _, buttonY = Point(detail.mapButton)

assert(nameY - detail.name:GetHeight() - subtitleY >= 6, "name and subtitle need space between them")
assert(portraitX + detail.portrait:GetWidth() + 9 < nameX, "the text column starts right of the portrait border")
assert(portraitY - detail.portrait:GetHeight() > cardDividerY, "the portrait stays inside the card")
assert(variantsY <= cardDividerY, "the variants heading sits below the card")
assert(slotY <= variantsY - detail.variantsBand:GetHeight(), "the slots sit below their heading")
assert(cardTitleY - cardStatusY >= 18, "the slot title sits above its status text")
assert(-cardStatusY + 14 <= slotHeight, "a status line stays inside its slot")
assert(slotY - slotHeight >= recordsY, "records start below the variant slots")
assert(recordsY == habitatY, "records and habitat share a heading line")
assert(locationY <= habitatY - detail.habitatBand:GetHeight(), "the map sits below its heading")
assert(locationY - detail.location:GetHeight() >= -514 + 6, "the map stays inside the pane")
assert(buttonY - detail.mapButton:GetHeight() >= -514 + 6, "the map button stays inside the pane")
print("detail layout: ok")
