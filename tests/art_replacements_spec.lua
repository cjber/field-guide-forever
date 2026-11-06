-- The approved native art: every journal bar is the client's ColoredProgressBarTemplate at its own 29 height, section
-- headings are the character sheet's title plate at its own 201 by 32, dividers are the options list's one-pixel rule,
-- and the removed glow layers stay gone.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns
local Art = ns.Art
local parent = harness.env.CreateFrame("Frame")

local function Point(widget)
	local point = widget:GetPoint(1)
	return point
end

-- Art.StatusBar: the client's template, its 15-high fill, and SetFillPercent as the only way it lengthens.
local bar = Art.StatusBar(parent, 320)
assert(bar.template == "ColoredProgressBarTemplate", "the status bar inherits the client's progress bar template")
assert(bar:GetWidth() == 320 and bar:GetHeight() == 29, "the bar keeps the template's 29 height")
assert(bar.Fill.atlas == "common-stat-bar-white" and bar.Fill.atlasUseSize, "the fill uses the template's white atlas")
assert(bar.Fill:GetHeight() == 15, "the fill keeps its 15 height")
assert(bar.Text:GetText() == "", "the template's own text stays empty")
bar:SetFillPercent(0.5)
assert(bar.fillPercent == 0.5 and bar.Fill:GetWidth() == 160, "SetFillPercent lengthens the fill by the bar's width")

-- Art.ObjectiveBar: the same template with a fraction, hidden at zero.
local progress = Art.ObjectiveBar(parent, 438)
assert(progress.template == "ColoredProgressBarTemplate", "the objective bar is the same client template")
progress:SetFraction(0.25)
assert(progress.fillPercent == 0.25, "the fraction reaches the client's fill")
progress:SetFraction(0)
assert(progress.Fill:IsShown() == false, "a zero fraction hides the fill")

-- Art.Header: the character sheet's title plate at its own size, the title centred.
local band, title = Art.Header(parent, "Variants")
assert(band.atlas == "UI-Character-Info-Title" and band.atlasUseSize, "the heading is the character sheet title plate")
assert(band:GetWidth() == 201 and band:GetHeight() == 32, "the title plate keeps its own 201 by 32")
assert(Point(title) == "CENTER", "the title is centred on the plate")

-- Art.Divider: the options list's rule at its native height, drawn to the surface's width.
local divider = Art.Divider(parent, 565)
assert(divider.atlas == "Options_HorizontalDivider" and divider.atlasUseSize, "the divider is the options rule")
assert(divider:GetHeight() == 1 and divider:GetWidth() == 565, "the rule keeps its one-pixel height")

-- The variant cards no longer carry a glow layer.
local detail = ns.Detail
detail.Create(harness.env.CreateFrame("Frame"))
for _, tier in ipairs({ "bronze", "silver", "gold", "shiny" }) do
	assert(rawget(detail.slots[tier], "Glow") == nil, tier .. " has no upgrade glow")
end

print("art replacements: ok")
