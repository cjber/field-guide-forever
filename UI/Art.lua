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

-- Native QuestionFrame Classic-zone illustrations; asset checks use tools/ui_art.py's reviewed build.
-- Content only: never used as frame chrome. Images showing Cataclysm terrain changes are omitted.
Art.LOCATION_ART = {
	[1] = 1851075, -- Dun Morogh
	[3] = 1851093, -- Badlands
	[8] = 1851108, -- Swamp of Sorrows
	[10] = 1851098, -- Duskwood
	[11] = 1851113, -- Wetlands
	[12] = 1851068, -- Elwynn Forest
	[14] = 1851076, -- Durotar
	[15] = 1851099, -- Dustwallow Marsh
	[17] = 1851084, -- The Barrens
	[28] = 1851112, -- Western Plaguelands
	[33] = 1851104, -- Stranglethorn Vale
	[44] = 1851085, -- Redridge Mountains
	[45] = 1851092, -- Arathi Highlands
	[46] = 1851095, -- Burning Steppes
	[47] = 1851103, -- The Hinterlands
	[51] = 1851105, -- Searing Gorge
	[85] = 1851089, -- Tirisfal Glades
	[130] = 1851086, -- Silverpine Forest
	[139] = 1851100, -- Eastern Plaguelands
	[141] = 1851088, -- Teldrassil
	[215] = 1851083, -- Mulgore
	[267] = 1851080, -- Hillsbrad Foothills
	[331] = 1851070, -- Ashenvale
	[357] = 1851102, -- Feralas
	[361] = 1851101, -- Felwood
	[440] = 1851109, -- Tanaris
	[490] = 1851111, -- Un'Goro Crater
	[618] = 1851114, -- Winterspring
	[1377] = 1851106, -- Silithus
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

---@param parent Frame
---@param key? string
---@param alpha? number
---@return Texture
function Art.Line(parent, key, alpha)
	local line = Art.Texture(parent, "ARTWORK", key or "border", alpha)
	line:SetHeight(1)
	return line
end

-- The status bar the Professions window uses for skill: gold fill in the client's progress frame. Every progress
-- figure in the journal uses this one style.
---@param parent Frame
---@param width number
---@param height number
---@param maxValue number
---@return StatusBar
function Art.StatusBar(parent, width, height, maxValue)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(width, height)
	bar:SetMinMaxValues(0, maxValue)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(Art.RGBA("gold", 1))
	local background = bar:CreateTexture(nil, "BACKGROUND")
	background:SetAtlas("Profession-ProgressBar-BG")
	background:SetAllPoints()
	local border = bar:CreateTexture(nil, "OVERLAY")
	border:SetAtlas("Profession-ProgressBar-frame")
	border:SetAllPoints()
	return bar
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
