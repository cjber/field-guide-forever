---@type string, FGNamespace
local _, ns = ...

-- The suite's palette in one place. Values are the approved mockup's, written as RGB triples so a texture colour
-- and a font colour can never drift apart.
---@class FGArt
local Art = {}
ns.Art = Art

Art.WHITE = "Interface\\Buttons\\WHITE8X8"
Art.BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"
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
	Humanoid = "Interface\\Icons\\INV_Misc_Head_Human_01",
	Undead = "Interface\\Icons\\Spell_Shadow_RaiseDead",
	Dragonkin = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
	Elemental = "Interface\\Icons\\Spell_Nature_Lightning",
	Giant = "Interface\\Icons\\Ability_Warrior_SavageBlow",
	Mechanical = "Interface\\Icons\\INV_Misc_Gear_01",
	Critter = "Interface\\Icons\\Ability_Hunter_BeastTaming",
	Demon = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
	Aberration = "Interface\\Icons\\Ability_Creature_Poison_01",
}

Art.CREATURE_FAMILY_ICONS = {
	Wolf = "Interface\\Icons\\ability_hunter_pet_wolf",
	Cat = "Interface\\Icons\\ability_hunter_pet_cat",
	Spider = "Interface\\Icons\\ability_hunter_pet_spider",
	Bear = "Interface\\Icons\\ability_hunter_pet_bear",
	Boar = "Interface\\Icons\\ability_hunter_pet_boar",
	Crocolisk = "Interface\\Icons\\ability_hunter_pet_crocolisk",
	["Carrion Bird"] = "Interface\\Icons\\ability_hunter_pet_bat",
	Raptor = "Interface\\Icons\\ability_hunter_pet_raptor",
	Tallstrider = "Interface\\Icons\\ability_hunter_pet_tallstrider",
	Scorpid = "Interface\\Icons\\ability_hunter_pet_scorpid",
	Turtle = "Interface\\Icons\\ability_hunter_pet_turtle",
	Bat = "Interface\\Icons\\ability_hunter_pet_bat",
	Hyena = "Interface\\Icons\\ability_hunter_pet_hyena",
	["Bird of Prey"] = "Interface\\Icons\\ability_hunter_pet_owl",
}

Art.GENERIC_CREATURE_ICON = "Interface\\Icons\\Ability_Hunter_BeastTaming"

-- A species shows its own kind, not a family glyph: a Prowler is a cat and a Zhevra is not a dragon. Each rule is
-- matched against the creature's name, in order, and the first hit wins; anything unmatched falls back to its
-- family icon. Every path here is art this client actually ships (checked against the pinned build's listfile).
Art.SPECIES_ICONS = {
	{
		"Interface\\Icons\\ability_hunter_pet_cat",
		"beast",
		{
			"prowler",
			"highmane",
			"nightsaber",
			"cougar",
			"tiger",
			"rake",
			"saber",
			"dishu",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_wolf",
		"beast",
		{
			"wolf",
			"coyote",
			"darkhound",
			"hound",
			"arugal",
			"worgen",
			"stalker",
			"fenros",
			"nefaru",
			"deeb",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_boar",
		"beast",
		{
			"boar",
			"goretusk",
			"bristleback",
			"quilboar",
			"bellygrub",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_tallstrider",
		"beast",
		{
			"plainstrider",
			"strider",
			"giraffe",
			"mazzranache",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_raptor",
		"beast",
		{
			"raptor",
			"scytheclaw",
			"taillasher",
			"scythemaw",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_scorpid",
		"beast",
		{
			"scorpid",
			"sting",
			"flayer",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_spider",
		"beast",
		{
			"spider",
			"tarantula",
			"venomfang",
			"lurker",
			"fang",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_crocolisk",
		"beast",
		{
			"crocolisk",
			"snapjaw",
			"gesharahan",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_hyena",
		"beast",
		{
			"hyena",
			"stormsnout",
		},
	},
	{
		"Interface\\Icons\\ability_mount_ridinghorse",
		"beast",
		{
			"zhevra",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_turtle",
		"beast",
		{
			"turtle",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_silithid",
		"beast",
		{
			"silithid",
			"swarmer",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_bear",
		"beast",
		{
			"bear",
			"grizzlegut",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_bat",
		"any",
		{
			"harpy",
			"windfury",
			"duskbat",
			"bat",
			"owl",
			"strigid",
			"screecher",
			"swoop",
			"buzzard",
			"condor",
			"thunderhawk",
			"hippogryph",
			"razorbeak",
			"fleshripper",
		},
	},
	{
		"Interface\\Icons\\ability_hunter_pet_worm",
		"beast",
		{
			"worm",
			"grub",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_tauren_01",
		"people",
		{
			"ogre",
			"mo'grosh",
			"kolkar",
			"galak",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_gnoll_01",
		"people",
		{
			"gnoll",
			"mongrel",
			"brute",
			"mystic",
			"basher",
			"trapper",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_kobold_01",
		"people",
		{
			"kobold",
			"trogg",
			"stonesplinter",
			"digger",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_murloc_01",
		"people",
		{
			"murloc",
			"puddlejumper",
			"oracle",
			"coastrunner",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_undead_01",
		"people",
		{
			"ghoul",
			"dead",
			"rot",
			"plague",
			"gorelix",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_human_01",
		"people",
		{
			"defias",
			"scarlet",
			"dalaran",
			"kul tiras",
			"human",
			"thug",
			"pillager",
			"looter",
			"highwayman",
			"smuggler",
			"blackguard",
			"mage",
			"guard",
			"theurgist",
			"sailor",
			"marine",
			"convert",
			"initiate",
			"warrior",
			"missionary",
			"scout",
			"palemane",
			"dustwind",
			"gnarlpine",
			"melanas",
			"ursal",
			"yowler",
			"zzarc",
			"slark",
			"goldtooth",
			"fedfennel",
			"gibblewilt",
			"galgosh",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_dragon_01",
		"people",
		{
			"dragon",
			"whelp",
			"drake",
		},
	},
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
	local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	bar:SetSize(width, height)
	Art.Card(bar, "background", 1)
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

---The thin client bezel that frames an icon everywhere in the interface, drawn over an icon texture.
---@param texture Texture
function Art.Bezel(texture)
	local border = texture:GetParent():CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Common\\WhiteIconFrame")
	local r, g, b = Art.RGBA("border", 0.85)
	border:SetVertexColor(r, g, b, 0.85)
	border:SetAllPoints(texture)
	texture.Bezel = border
	return border
end

---@param family string?
---@return string
function Art.FamilyIcon(family)
	return Art.FAMILY_ICONS[family] or Art.GENERIC_CREATURE_ICON
end

---The icon a species shows: its generated model icon, name refinement, then family and creature-type art.
---@param name string
---@param npcID integer
---@return string
function Art.SpeciesIcon(name, npcID)
	local needle = name:lower()
	local typeID, familyID, modelIcon = ns.CreatureInfo.Get(npcID)
	if modelIcon then
		return "Interface\\Icons\\" .. modelIcon:gsub("^interface/icons/", "")
	end
	local family = familyID and ns.ClientData.families[familyID]
	local creatureType = typeID and ns.CreatureInfo.types[typeID]
	local side = "people"
	if creatureType == "Beast" or (familyID and familyID > 0) then
		side = "beast"
	end
	for _, rule in ipairs(Art.SPECIES_ICONS) do
		if rule[2] == "any" or rule[2] == side then
			for _, keyword in ipairs(rule[3]) do
				if needle:find(keyword, 1, true) then
					return rule[1]
				end
			end
		end
	end
	if family then
		return Art.CREATURE_FAMILY_ICONS[family] or Art.FAMILY_ICONS[creatureType] or Art.GENERIC_CREATURE_ICON
	end
	return Art.FAMILY_ICONS[creatureType] or Art.GENERIC_CREATURE_ICON
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
