---@type string, BFNamespace
local _, ns = ...

-- The suite's palette in one place. Values are the approved mockup's, written as RGB triples so a texture colour
-- and a font colour can never drift apart.
---@class BFArt
local Art = {}
ns.Art = Art

Art.WHITE = "Interface\\Buttons\\WHITE8X8"
Art.PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

Art.COLORS = {
	background = { 0.043, 0.047, 0.055 },
	panel = { 0.13, 0.14, 0.16 },
	border = { 0.72, 0.63, 0.42 },
	gold = { 0.88, 0.71, 0.25 },
	text = { 0.89, 0.85, 0.76 },
	muted = { 0.62, 0.60, 0.55 },
	rare = { 0.52, 0.72, 0.95 },
	shiny = { 0.88, 0.71, 0.25 },
	complete = { 0.49, 0.60, 0.38 },
}

Art.FAMILY_ICONS = {
	Beast = "Interface\\Icons\\Ability_Hunter_BeastTaming",
	Humanoid = "Interface\\Icons\\Ability_Warrior_BattleShout",
	Undead = "Interface\\Icons\\Spell_Shadow_RaiseDead",
	Dragonkin = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
	Elemental = "Interface\\Icons\\Spell_Fire_Fire",
	Giant = "Interface\\Icons\\Ability_Warrior_Cleave",
	Mechanical = "Interface\\Icons\\Trade_Engineering",
	Critter = "Interface\\Icons\\INV_Misc_PocketWatch_01",
	Demon = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
	Aberration = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
}

---@param key string
---@param alpha? number
---@return number, number, number, number
function Art.RGBA(key, alpha)
	local color = Art.COLORS[key] or Art.COLORS.text
	return color[1], color[2], color[3], alpha or 1
end

---@param key string
---@param alpha? number
---@return ColorMixin?
function Art.Color(key, alpha)
	if not CreateColor then
		return nil
	end
	local r, g, b, a = Art.RGBA(key, alpha)
	return CreateColor(r, g, b, a)
end

---@param texture Texture
---@param key string
---@param alpha? number
function Art.Paint(texture, key, alpha)
	local r, g, b, a = Art.RGBA(key, alpha)
	texture:SetTexture(Art.WHITE)
	texture:SetVertexColor(r, g, b, a)
end

---@param parent Frame
---@param layer? string
---@param key? string
---@param alpha? number
---@return Texture
function Art.Texture(parent, layer, key, alpha)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK")
	Art.Paint(texture, key or "text", alpha)
	return texture
end

---@param frame Frame
---@param colorKey? string
---@param alpha? number
function Art.Card(frame, colorKey, alpha)
	if not frame.SetBackdrop then
		return
	end
	frame:SetBackdrop({
		bgFile = Art.WHITE,
		edgeFile = Art.WHITE,
		tile = false,
		edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	local r, g, b = Art.RGBA(colorKey or "panel", alpha or 1)
	frame:SetBackdropColor(r, g, b, alpha or 1)
	local br, bg, bb = Art.RGBA("border", 0.8)
	frame:SetBackdropBorderColor(br, bg, bb, 0.8)
end

---@param frame Frame
function Art.Panel(frame)
	if not frame.SetBackdrop then
		return
	end
	frame:SetBackdrop({
		bgFile = Art.WHITE,
		edgeFile = Art.WHITE,
		tile = false,
		edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	local r, g, b = Art.RGBA("background", 0.98)
	frame:SetBackdropColor(r, g, b, 0.98)
	local br, bg, bb = Art.RGBA("border", 0.9)
	frame:SetBackdropBorderColor(br, bg, bb, 0.9)
end

---@param frame Frame
function Art.Flatten(frame)
	if frame.SetBackdrop then
		frame:SetBackdrop(nil)
	end
	if frame.SetBackdropColor then
		frame:SetBackdropColor(0, 0, 0, 0)
	end
end

---@param parent Frame
---@param key? string
---@param alpha? number
---@return Texture
function Art.Line(parent, key, alpha)
	local line = Art.Texture(parent, "ARTWORK", key or "border", alpha)
	line:SetHeight(1)
	return line
end

---@param parent Frame
---@param width number
---@param height number
---@param key? string
---@return Frame bar
---@return Texture fill
function Art.Bar(parent, width, height, key)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetSize(width, height)
	local background = Art.Texture(bar, "BACKGROUND", "background", 1)
	background:SetAllPoints(bar)
	local fill = Art.Texture(bar, "ARTWORK", key or "gold", 1)
	fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
	fill:SetHeight(height - 2)
	fill:SetWidth(0)
	bar.Fill = fill
	return bar, fill
end

---@param parent Frame
---@param font? string
---@param key? string
---@return FontString
function Art.Text(parent, font, key)
	local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
	local r, g, b = Art.RGBA(key or "text", 1)
	text:SetTextColor(r, g, b, 1)
	return text
end

---@param texture Texture
---@param file string
---@param size number
function Art.Icon(texture, file, size)
	texture:SetTexCoord(0, 1, 0, 1)
	texture:SetTexture(file)
	texture:SetSize(size, size)
end

---@param family string?
---@return string
function Art.FamilyIcon(family)
	return Art.FAMILY_ICONS[family] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

---@param texture Texture
function Art.MakePortrait(texture)
	if not texture.AddMaskTexture then
		return
	end
	local mask = texture:GetParent():CreateMaskTexture()
	mask:SetTexture(Art.PORTRAIT_MASK)
	mask:SetAllPoints(texture)
	texture:AddMaskTexture(mask)
end

---@param parent Frame
---@param size number
---@return Texture
function Art.Portrait(parent, size)
	local texture = parent:CreateTexture(nil, "ARTWORK")
	texture:SetSize(size, size)
	Art.MakePortrait(texture)
	return texture
end
