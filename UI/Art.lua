---@type string, FGNamespace
local _, ns = ...

-- The suite's palette in one place. Values are the approved mockup's, written as RGB triples so a texture colour
-- and a font colour can never drift apart.
---@class FGArt
local Art = {}
ns.Art = Art

Art.WHITE = "Interface\\Buttons\\WHITE8X8"
Art.BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"

-- One mark per variant: the Professions window's crafting quality marks, one to four, so the ladder reads as a rising
-- quality rather than money.
Art.TIER_ICONS = {
	bronze = "Professions-Icon-Quality-Tier1",
	silver = "Professions-Icon-Quality-Tier2",
	gold = "Professions-Icon-Quality-Tier3",
	shiny = "Professions-Icon-Quality-Tier4",
}

Art.COLORS = {
	background = { 0.043, 0.047, 0.055 },
	panel = { 0.13, 0.14, 0.16 },
	border = { 0.72, 0.63, 0.42 },
	gold = { 0.91, 0.74, 0.39 },
	bronze = { 0.78, 0.53, 0.35 },
	silver = { 0.79, 0.82, 0.86 },
	shiny = { 0.73, 0.90, 1 },
	text = { 0.89, 0.85, 0.76 },
	muted = { 0.62, 0.60, 0.55 },
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

-- The Dungeon Finder's own instance pictures, by instance Map ID. Content only; a missing instance shows the book.
Art.INSTANCE_ICONS = {
	[33] = "Interface\\LFGFrame\\LFGIcon-ShadowfangKeep",
	[34] = "Interface\\LFGFrame\\LFGIcon-StormwindStockades",
	[36] = "Interface\\LFGFrame\\LFGIcon-Deadmines",
	[43] = "Interface\\LFGFrame\\LFGIcon-WailingCaverns",
	[47] = "Interface\\LFGFrame\\LFGIcon-RazorfenKraul",
	[48] = "Interface\\LFGFrame\\LFGIcon-BlackfathomDeeps",
	[70] = "Interface\\LFGFrame\\LFGIcon-Uldaman",
	[90] = "Interface\\LFGFrame\\LFGIcon-Gnomeregan",
	[109] = "Interface\\LFGFrame\\LFGIcon-SunkenTemple",
	[129] = "Interface\\LFGFrame\\LFGIcon-RazorfenDowns",
	[189] = "Interface\\LFGFrame\\LFGIcon-ScarletMonastery",
	[209] = "Interface\\LFGFrame\\LFGIcon-ZulFarak",
	[229] = "Interface\\LFGFrame\\LFGIcon-BlackrockSpire",
	[230] = "Interface\\LFGFrame\\LFGIcon-BlackrockDepths",
	[249] = "Interface\\LFGFrame\\LFGIcon-OnyxiaEncounter",
	[289] = "Interface\\LFGFrame\\LFGIcon-Scholomance",
	[309] = "Interface\\LFGFrame\\LFGIcon-ZulGurub",
	[329] = "Interface\\LFGFrame\\LFGIcon-Stratholme",
	[349] = "Interface\\LFGFrame\\LFGIcon-Maraudon",
	[389] = "Interface\\LFGFrame\\LFGIcon-RagefireChasm",
	[409] = "Interface\\LFGFrame\\LFGIcon-MoltenCore",
	[429] = "Interface\\LFGFrame\\LFGIcon-DireMaul",
	[469] = "Interface\\LFGFrame\\LFGIcon-BlackwingLair",
	[509] = "Interface\\LFGFrame\\LFGIcon-AQRuins",
	[531] = "Interface\\LFGFrame\\LFGIcon-AQTemple",
	[533] = "Interface\\LFGFrame\\LFGIcon-Naxxramas",
}

Art.FAMILY_ICONS = {
	Beast = "Interface\\Icons\\Ability_Hunter_BeastTaming",
	Humanoid = "Interface\\Icons\\INV_Misc_Head_Human_01",
	Undead = "Interface\\Icons\\Spell_Shadow_RaiseDead",
	Dragonkin = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
	Elemental = "Interface\\Icons\\Spell_Nature_Lightning",
	Giant = "Interface\\Icons\\Ability_Warrior_SavageBlow",
	Mechanical = "Interface\\Icons\\INV_Misc_Gear_01",
	Critter = "Interface\\Icons\\pet_type_critter",
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
	-- Critters and plants read as themselves even when the model lookup misses them. Word boundaries keep a name
	-- such as Yowler from borrowing an owl.
	{
		"Interface\\Icons\\inv_babydeer",
		"any",
		{
			"deer",
			"fawn",
			"stag",
			"doe",
			"gazelle",
		},
	},
	{
		"Interface\\Icons\\inv_squirrelardenweald",
		"any",
		{
			"squirrel",
		},
	},
	{
		"Interface\\Icons\\inv_pet_toad_green",
		"any",
		{
			"toad",
			"frog",
		},
	},
	{
		"Interface\\Icons\\inv_misc_rabbit",
		"any",
		{
			"rabbit",
			"hare",
			"bunny",
		},
	},
	{
		"Interface\\Icons\\inv_pet_mouse",
		"any",
		{
			"mouse",
			"rat",
			"vole",
			"shrew",
		},
	},
	{
		"Interface\\Icons\\inv_pet_skunk",
		"any",
		{
			"skunk",
		},
	},
	{
		"Interface\\Icons\\inv_pet_raccoon",
		"any",
		{
			"raccoon",
		},
	},
	{
		"Interface\\Icons\\inv_pet_otter",
		"any",
		{
			"otter",
		},
	},
	{
		"Interface\\Icons\\inv_pet_beaver",
		"any",
		{
			"beaver",
		},
	},
	{
		"Interface\\Icons\\inv_pet_porcupine",
		"any",
		{
			"porcupine",
			"quillrat",
		},
	},
	{
		"Interface\\Icons\\inv_pet_prairiedog",
		"any",
		{
			"prairie dog",
			"prairiedog",
		},
	},
	{
		"Interface\\Icons\\inv_pet_wisp_purple",
		"any",
		{
			"wisp",
		},
	},
	{
		"Interface\\Icons\\inv_pet_ancientprotector",
		"any",
		{
			"treant",
			"ancient of",
			"ancient protector",
			"keeper of the grove",
			"grove keeper",
			"protector of the grove",
		},
	},
	{
		"Interface\\Icons\\inv_duck_white",
		"any",
		{
			"duck",
			"goose",
		},
	},
	{
		"Interface\\Icons\\inv_misc_seagullpet_01",
		"any",
		{
			"seagull",
		},
	},
	{
		"Interface\\Icons\\inv_pet_babycrane",
		"any",
		{
			"crane",
			"heron",
		},
	},
	{
		"Interface\\Icons\\inv_pet_peacock_blue",
		"any",
		{
			"peacock",
		},
	},
	-- The races the model stem table cannot name fall back to their own head, not a shared humanoid glyph.
	{
		"Interface\\Icons\\inv_misc_head_dwarf_01",
		"people",
		{
			"dwarf",
			"ironforge",
			"dark iron",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_gnome_01",
		"people",
		{
			"gnome",
			"gnomish",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_elf_01",
		"people",
		{
			"night elf",
			"nightelf",
			"kaldorei",
			"blood elf",
			"highelf",
			"high elf",
			"sin'dorei",
			"quel'dorei",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_orc_01",
		"people",
		{
			"orc",
			"warsong",
			"frostwolf",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_troll_01",
		"people",
		{
			"troll",
			"darkspear",
			"amani",
			"gurubashi",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_tauren_01",
		"people",
		{
			"tauren",
			"grimtotem",
		},
	},
	{
		"Interface\\Icons\\inv_misc_head_undead_01",
		"people",
		{
			"undead",
			"scourge",
			"forsaken",
			"skeleton",
			"zombie",
			"banshee",
			"lich",
		},
	},
	{
		"Interface\\Icons\\achievement_goblinhead",
		"people",
		{
			"goblin",
			"steamwheedle",
			"bilgewater",
		},
	},
	{
		"Interface\\Icons\\inv_misc_nagamale",
		"any",
		{
			"naga",
			"siren",
			"lobstrok",
		},
	},
	{
		"Interface\\Icons\\spell_shadow_metamorphosis",
		"any",
		{
			"satyr",
			"felguard",
			"succubus",
			"doomguard",
			"voidwalker",
			"dreadlord",
		},
	},
	{
		"Interface\\Icons\\hunter_pvp_direbeastbasilisk",
		"beast",
		{
			"basilisk",
		},
	},
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

-- The client's own progress bar, inherited from ColoredProgressBarTemplate: its white fill over the frame that carries
-- the border, masked at both ends. The template is 29 high and its fill 15; only the width changes, through the
-- template's SetFillPercent, which is the only way the client lengthens one of its bars.
---@class FGProgressBar : Frame
---@field Fill Texture
---@field Mask Texture
---@field Text FontString
---@field SetFillPercent fun(self: FGProgressBar, percent: number)

---@param parent Frame
---@param width number
---@return FGProgressBar
function Art.StatusBar(parent, width)
	local bar = CreateFrame("Frame", nil, parent, "ColoredProgressBarTemplate") --[[@as FGProgressBar]]
	bar:SetSize(width, 29)
	bar.Text:SetText("")
	bar.Fill:SetVertexColor(Art.RGBA("gold", 1))
	bar:SetFillPercent(0)
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

-- A whole word, so "Yowler" is not an owl and "Combat" is not a bat. Apostrophes and digits end a word.
---@param haystack string
---@param word string
---@return boolean
local function HasWord(haystack, word)
	local start = 1
	while true do
		local first = haystack:find(word, start, true)
		if not first then
			return false
		end
		local before = first > 1 and haystack:sub(first - 1, first - 1) or ""
		local after = haystack:sub(first + #word, first + #word)
		if not before:match("%a") and not after:match("%a") then
			return true
		end
		start = first + 1
	end
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
	if creatureType == "Beast" or creatureType == "Critter" or (familyID and familyID > 0) then
		side = "beast"
	end
	for _, rule in ipairs(Art.SPECIES_ICONS) do
		if rule[2] == "any" or rule[2] == side then
			for _, keyword in ipairs(rule[3]) do
				if HasWord(needle, keyword) then
					return rule[1]
				end
			end
		end
	end
	return family and Art.CREATURE_FAMILY_ICONS[family] or Art.FAMILY_ICONS[creatureType] or Art.GENERIC_CREATURE_ICON
end

-- A row's creature shows its real face when the catalogue knows a client display ID, and the species fallback art
-- when it does not. One call per recycled row, never from OnUpdate.
---@param texture Texture
---@param name string
---@param npcID integer
---@param size number
function Art.CreatureIcon(texture, name, npcID, size)
	local _, _, _, displayID = ns.CreatureInfo.Get(npcID)
	texture:SetTexCoord(0, 1, 0, 1)
	texture:SetSize(size, size)
	if displayID and SetPortraitTextureFromCreatureDisplayID then
		SetPortraitTextureFromCreatureDisplayID(texture, displayID)
		return
	end
	texture:SetTexture(Art.SpeciesIcon(name, npcID))
end

-- Draw one variant's quality mark on a texture. A nil tier leaves the caller to hide the texture.
---@param texture Texture
---@param tier string?
---@param size number
function Art.PaintTierIcon(texture, tier, size)
	texture:SetSize(size, size)
	if tier and Art.TIER_ICONS[tier] then
		texture:SetAtlas(Art.TIER_ICONS[tier])
	end
end

-- A section heading as the character sheet draws one: the client's title plate at its own 201 by 32, the title
-- centred on it 1 above the middle (CharacterStatFrameCategoryTemplate). Every heading shares that one plate size.
---@param parent Frame
---@param text string
---@return Texture band, FontString title
function Art.Header(parent, text)
	local band = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
	band:SetAtlas("UI-Character-Info-Title", true)
	local title = Art.Text(parent, "GameFontNormalLarge", "gold")
	title:SetPoint("CENTER", band, "CENTER", 0, 1)
	title:SetText(text)
	return band, title
end

-- The progress bar with a fraction instead of a value: the same client template, the fill hidden at zero because the
-- client treats a zero width as unset.
---@class FGObjectiveBar : FGProgressBar
---@field SetFraction fun(self: FGObjectiveBar, fraction: number)

---@param parent Frame
---@param width number
---@return FGObjectiveBar
function Art.ObjectiveBar(parent, width)
	local bar = Art.StatusBar(parent, width) --[[@as FGObjectiveBar]]
	function bar:SetFraction(fraction)
		self:SetFillPercent(fraction)
		self.Fill:SetShown(fraction > 0)
	end
	bar:SetFraction(0)
	return bar
end

-- The options list's horizontal rule at its native one-pixel height, drawn to the width of the surface it closes.
---@param parent Frame
---@param width number
---@return Texture
function Art.Divider(parent, width)
	local divider = parent:CreateTexture(nil, "BORDER")
	divider:SetAtlas("Options_HorizontalDivider", true)
	divider:SetWidth(width)
	return divider
end

-- An icon in the Collections journal's item border: gold when collected, grey when not.
---@param parent Frame
---@param size number the border's size; the icon sits inside it at about four fifths
---@return Texture icon, Texture border
function Art.BorderedIcon(parent, size)
	local icon = parent:CreateTexture(nil, "ARTWORK")
	local inset = math.floor(size * 0.1 + 0.5)
	icon:SetSize(size - inset * 2, size - inset * 2)
	local border = parent:CreateTexture(nil, "OVERLAY")
	border:SetSize(size, size)
	border:SetPoint("CENTER", icon, "CENTER")
	return icon, border
end

---@param border Texture
---@param collected boolean
function Art.SetBorderCollected(border, collected)
	border:SetAtlas(collected and "collections-itemborder-collected" or "collections-itemborder-uncollected")
end

-- A uiMap's world map art fully explored: the base tiles from C_Map, with every exploration overlay from the
-- generated ns.ClientData.mapOverlays laid on top the way MapExplorationPinMixin:RefreshOverlays lays them out, all
-- scaled to the frame's width and clipped to it.
---@class FGZoneMap : Frame
---@field tiles Texture[]
---@field markers Texture[]

---@param parent Frame
---@param width number
---@param height number
---@return FGZoneMap
function Art.ZoneMap(parent, width, height)
	local map = CreateFrame("Frame", nil, parent) --[[@as FGZoneMap]]
	map:SetSize(width, height)
	map:SetClipsChildren(true)
	map.tiles = {}
	map.markers = {}
	return map
end

-- Fill the inset with the layer at its own aspect (cover, centred) so no zone is squashed into another's shape. Tiles
-- are cropped to the layer's real extent, and the last column and row may be partial. `points` are 0..1 coordinates
-- with north at y=0, drawn as the client's map pin.
---@param map FGZoneMap
---@param uiMapID integer?
---@param points { [1]: number, [2]: number }[]?
---@return boolean drawn
function Art.SetZoneMap(map, uiMapID, points)
	local used = 0
	local function Place(file, x, y, w, h, right, bottom, sublevel)
		used = used + 1
		local texture = map.tiles[used]
		if not texture then
			texture = map:CreateTexture(nil, "ARTWORK")
			map.tiles[used] = texture
		end
		texture:SetDrawLayer("ARTWORK", sublevel)
		texture:SetTexture(file)
		texture:SetTexCoord(0, right, 0, bottom)
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", map, "TOPLEFT", x, -y)
		texture:SetSize(w, h)
		texture:Show()
	end
	local layers = uiMapID and C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(uiMapID)
	local info = layers and layers[1]
	local files = info and uiMapID and C_Map.GetMapArtLayerTextures(uiMapID, 1)
	local offsetX, offsetY, scale = 0, 0, 1
	local drawn = false
	if info and files and #files > 0 then
		drawn = true
		scale = math.max(map:GetWidth() / info.layerWidth, map:GetHeight() / info.layerHeight)
		offsetX = (map:GetWidth() - info.layerWidth * scale) / 2
		offsetY = (map:GetHeight() - info.layerHeight * scale) / 2
		local tileW, tileH = info.tileWidth, info.tileHeight
		local columns = math.ceil(info.layerWidth / tileW)
		for index = 1, #files do
			local file = files[index]
			local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
			local pixelW = math.min(tileW, info.layerWidth - column * tileW)
			local pixelH = math.min(tileH, info.layerHeight - row * tileH)
			if pixelW > 0 and pixelH > 0 then
				local fileW, fileH = 16, 16
				while fileW < pixelW do
					fileW = fileW * 2
				end
				while fileH < pixelH do
					fileH = fileH * 2
				end
				Place(
					file,
					offsetX + column * tileW * scale,
					offsetY + row * tileH * scale,
					pixelW * scale,
					pixelH * scale,
					pixelW / fileW,
					pixelH / fileH,
					0
				)
			end
		end
		for _, overlay in ipairs(ns.ClientData.mapOverlays[uiMapID] or {}) do
			local overlayX, overlayY, overlayW, overlayH, ids =
				overlay[1], overlay[2], overlay[3], overlay[4], overlay[5]
			local wide, tall = math.ceil(overlayW / tileW), math.ceil(overlayH / tileH)
			for row = 1, tall do
				local pixelH = row < tall and tileH or (overlayH - (tall - 1) * tileH)
				local fileH = row < tall and tileH or 16
				while fileH < pixelH do
					fileH = fileH * 2
				end
				for column = 1, wide do
					local pixelW = column < wide and tileW or (overlayW - (wide - 1) * tileW)
					local fileW = column < wide and tileW or 16
					while fileW < pixelW do
						fileW = fileW * 2
					end
					local file = ids[(row - 1) * wide + column]
					if file then
						Place(
							file,
							offsetX + (overlayX + tileW * (column - 1)) * scale,
							offsetY + (overlayY + tileH * (row - 1)) * scale,
							pixelW * scale,
							pixelH * scale,
							pixelW / fileW,
							pixelH / fileH,
							1
						)
					end
				end
			end
		end
	end
	for index = used + 1, #map.tiles do
		map.tiles[index]:Hide()
	end
	local usedMarkers = 0
	if drawn and info then
		for _, point in ipairs(points or {}) do
			usedMarkers = usedMarkers + 1
			local marker = map.markers[usedMarkers]
			if not marker then
				marker = map:CreateTexture(nil, "OVERLAY")
				marker:SetAtlas("Waypoint-MapPin-Tracked")
				map.markers[usedMarkers] = marker
			end
			marker:SetSize(15, 15)
			marker:ClearAllPoints()
			marker:SetPoint(
				"CENTER",
				map,
				"TOPLEFT",
				offsetX + point[1] * info.layerWidth * scale,
				-(offsetY + point[2] * info.layerHeight * scale)
			)
			marker:Show()
		end
	end
	for index = usedMarkers + 1, #map.markers do
		map.markers[index]:Hide()
	end
	return drawn or false
end
