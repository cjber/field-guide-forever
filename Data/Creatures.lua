---@type string, BFNamespace
local _, ns = ...

-- Real Classic creatures, grouped by the zone a field journal would open on. Ids are stable: a saved entry keeps
-- its species when names or level ranges are corrected around it.
---@param id integer
---@param name string
---@param family BFFamily
---@param minLevel integer
---@param maxLevel integer
---@param lore string
---@param rare? boolean
---@return BFSpecies
local function mob(id, name, family, minLevel, maxLevel, lore, rare)
	return {
		id = id,
		name = name,
		family = family,
		minLevel = minLevel,
		maxLevel = maxLevel,
		lore = lore,
		rare = rare or nil,
	}
end

---@param name string
---@param continent string
---@param species BFSpecies[]
---@return BFZone
local function zone(name, continent, species)
	for _, entry in ipairs(species) do
		entry.zone = name
	end
	return { name = name, continent = continent, species = species }
end

ns.Creatures = {
	zones = {
		zone("The Barrens", "Kalimdor", {
			mob(
				1001,
				"Plainstrider",
				"Beast",
				10,
				12,
				"The Barrens' great striders cross the dry grass in nervous, chattering flocks."
			),
			mob(
				1002,
				"Adult Plainstrider",
				"Beast",
				13,
				15,
				"Older striders keep watch over the flock and raise a shrill alarm at the first scent of a hunter."
			),
			mob(
				1003,
				"Savannah Prowler",
				"Beast",
				14,
				16,
				"Savannah prowlers stalk the golden grass in silence until the last possible moment."
			),
			mob(
				1004,
				"Savannah Highmane",
				"Beast",
				17,
				19,
				"A highmane's dark ruff marks the leader of a pride that rules a stretch of open savannah."
			),
			mob(
				1005,
				"Zhevra Runner",
				"Beast",
				12,
				14,
				"Zhevra runners travel in quick, loose herds and bolt at the snap of a twig."
			),
			mob(
				1006,
				"Zhevra Charger",
				"Beast",
				16,
				18,
				"A charger lowers its single horn and holds its ground while the herd escapes."
			),
			mob(
				1007,
				"Bristleback Boar",
				"Beast",
				10,
				12,
				"Bristleback boars root through the red earth and defend their wallows with sudden fury."
			),
			mob(
				1008,
				"Bristleback Quilboar",
				"Humanoid",
				11,
				13,
				"Quilboar scouts watch the roads from thorn fences, ready to whistle a warning back to camp."
			),
			mob(
				1009,
				"Razormane Scavenger",
				"Humanoid",
				12,
				14,
				"Razormane scavengers pick over abandoned camps and carry off anything that glints."
			),
			mob(
				1010,
				"Razormane Thornweaver",
				"Humanoid",
				15,
				17,
				"Thornweavers bind brambles into snares and speak of the old quilboar warrens with pride."
			),
			mob(
				1011,
				"Kolkar Wrangler",
				"Humanoid",
				13,
				15,
				"Kolkar wranglers drive stolen beasts across the Barrens and answer trespass with a spear."
			),
			mob(
				1012,
				"Kolkar Stormer",
				"Humanoid",
				15,
				17,
				"A stormer calls the dry wind down from the mesas and hurls it at anyone who follows."
			),
			mob(
				1013,
				"Thunderhead Hippogryph",
				"Beast",
				16,
				18,
				"Thunderhead hippogryphs nest high in the crags and dive at intruders with talons spread."
			),
			mob(
				1014,
				"Oasis Snapjaw",
				"Beast",
				15,
				17,
				"Snapjaws bask at the water's edge, patient as stones until something leans too close."
			),
			mob(
				1015,
				"Sunscale Scytheclaw",
				"Beast",
				16,
				18,
				"Sunscale scytheclaws hunt in pairs across the open flats, their calls carrying for miles."
			),
			mob(
				1016,
				"Silithid Swarmer",
				"Beast",
				17,
				19,
				"Silithid swarmers pour from hidden burrows in a clicking, many-legged tide."
			),
			mob(
				1017,
				"Stormsnout",
				"Beast",
				18,
				20,
				"The stormsnout's hide carries the smell of ozone long after a dry lightning storm has passed."
			),
			mob(
				1018,
				"Barrens Giraffe",
				"Critter",
				12,
				14,
				"Barrens giraffes browse the highest branches and watch the horizon with calm, unblinking eyes."
			),
			mob(
				1019,
				"Dishu",
				"Beast",
				13,
				13,
				"Dishu is a pale lion known to the Barrens' hunters by the claw marks left on old fence posts.",
				true
			),
			mob(
				1020,
				"Gesharahan",
				"Beast",
				17,
				17,
				"Gesharahan, a wind serpent of the dry gullies, is said to strike before its shadow moves.",
				true
			),
		}),
		zone("Durotar", "Kalimdor", {
			mob(
				1101,
				"Mottled Boar",
				"Beast",
				1,
				3,
				"Mottled boars snuffle through the red dust around the Valley of Trials."
			),
			mob(
				1102,
				"Dire Mottled Boar",
				"Beast",
				4,
				6,
				"Dire mottled boars carry old scars and charge anything that enters their wallow."
			),
			mob(
				1103,
				"Elder Mottled Boar",
				"Beast",
				7,
				9,
				"An elder boar's tusks are chipped from years of digging and fighting."
			),
			mob(
				1104,
				"Scorpid Worker",
				"Beast",
				1,
				3,
				"Scorpid workers haul food into the nest and raise their tails at the first threat."
			),
			mob(
				1105,
				"Clattering Scorpid",
				"Beast",
				4,
				6,
				"A clattering scorpid announces itself with a dry rattle before it strikes."
			),
			mob(
				1106,
				"Vile Familiar",
				"Demon",
				3,
				5,
				"Vile familiars skulk near the burning crystals and answer only to the warlocks who called them."
			),
			mob(
				1107,
				"Felstalker",
				"Demon",
				6,
				8,
				"Felstalkers run in lean, hungry packs, their breath sour with fel fire."
			),
			mob(
				1108,
				"Bloodtalon Taillasher",
				"Beast",
				4,
				6,
				"Bloodtalon taillashes whip the shallows into foam when a stranger approaches the nest."
			),
			mob(
				1109,
				"Bloodtalon Scythemaw",
				"Beast",
				7,
				9,
				"The scythemaw's broad beak can shear through shell and bone alike."
			),
			mob(
				1110,
				"Durotar Tiger",
				"Beast",
				6,
				8,
				"Durotar tigers keep to the rocky ridges and descend only when hunger drives them."
			),
			mob(
				1111,
				"Dustwind Savager",
				"Humanoid",
				7,
				9,
				"Dustwind savagers paint their faces with ochre and guard the harpy nests above the coast."
			),
			mob(
				1112,
				"Dustwind Storm Witch",
				"Humanoid",
				8,
				10,
				"Storm witches sing to the sea wind and send sudden squalls against the villages below."
			),
			mob(
				1113,
				"Razorbeak Skylord",
				"Beast",
				8,
				10,
				"The skylord circles high above the canyon, watching for anything small enough to carry off."
			),
			mob(
				1114,
				"Razorbeak Ambusher",
				"Beast",
				6,
				8,
				"Razorbeak ambushers wait on the cliff ledges and drop without a sound."
			),
			mob(
				1115,
				"Kul Tiras Sailor",
				"Humanoid",
				5,
				7,
				"Kul Tiras sailors hold the coast for their captain, far from the streets of Boralus."
			),
			mob(
				1116,
				"Kul Tiras Marine",
				"Humanoid",
				7,
				9,
				"The marines drill on the beach at dawn and treat every Durotar trail as enemy ground."
			),
			mob(
				1117,
				"Vile Sting",
				"Beast",
				9,
				9,
				"Vile Sting is a scorpid whose venom stains the sand dark wherever it has fed.",
				true
			),
			mob(
				1118,
				"Death Flayer",
				"Beast",
				7,
				7,
				"Death Flayer's pale shell is easy to spot, but few hunters live to boast of the sight.",
				true
			),
		}),
		zone("Mulgore", "Kalimdor", {
			mob(
				1201,
				"Plainstrider",
				"Beast",
				1,
				3,
				"Mulgore's striders wander the tall grass in easy, unbothered groups."
			),
			mob(
				1202,
				"Adult Plainstrider",
				"Beast",
				4,
				6,
				"Adult striders guard the young with sharp beaks and loud, rolling cries."
			),
			mob(
				1203,
				"Prairie Wolf",
				"Beast",
				1,
				3,
				"Prairie wolves trot along the ridge lines and sleep in the lee of the red rocks."
			),
			mob(
				1204,
				"Prairie Stalker",
				"Beast",
				4,
				6,
				"A prairie stalker will shadow a traveler for miles before deciding whether to close."
			),
			mob(
				1205,
				"Swoop",
				"Beast",
				3,
				5,
				"Swoops spiral over the plains on broad wings, crying down at anything that moves."
			),
			mob(
				1206,
				"Windfury Harpy",
				"Humanoid",
				3,
				5,
				"Windfury harpies build twig nests on the cliffs and quarrel over every scrap."
			),
			mob(
				1207,
				"Windfury Wind Witch",
				"Humanoid",
				6,
				8,
				"Wind witches carry the voice of the gale and use it to confuse hunters in the grass."
			),
			mob(
				1208,
				"Bristleback Boar",
				"Beast",
				4,
				6,
				"Bristleback boars leave deep furrows where they have rooted for tubers."
			),
			mob(
				1209,
				"Bristleback Shaman",
				"Humanoid",
				6,
				8,
				"The quilboar shaman paints bones with red clay and calls on the thorn spirits."
			),
			mob(
				1210,
				"Palemane Tanner",
				"Humanoid",
				1,
				3,
				"Palemane tanners work hides at the edge of camp, always watching the trail."
			),
			mob(
				1211,
				"Palemane Skinner",
				"Humanoid",
				3,
				5,
				"Skinners carry long blades and know exactly how to use them on more than hides."
			),
			mob(
				1212,
				"Palemane Poacher",
				"Humanoid",
				6,
				8,
				"Poachers set wire snares in the grass and resent anyone who finds them first."
			),
			mob(
				1213,
				"Galak Messenger",
				"Humanoid",
				4,
				6,
				"A Galak messenger runs the long road between camps with a spear never far from hand."
			),
			mob(
				1214,
				"Mountain Cougar",
				"Beast",
				5,
				7,
				"Mountain cougars hunt the slopes at dusk and leave little more than a drag mark."
			),
			mob(
				1215,
				"Stalking Plainstrider",
				"Beast",
				7,
				9,
				"Stalking striders freeze at the sound of footsteps, then burst away through the grass."
			),
			mob(
				1216,
				"Thunderhawk",
				"Beast",
				8,
				10,
				"Thunderhawks ride the thermals above the plains and stoop like falling stones."
			),
			mob(
				1217,
				"The Rake",
				"Beast",
				10,
				10,
				"The Rake is a great tawny lion whose roar carries across the whole of Mulgore.",
				true
			),
			mob(
				1218,
				"Mazzranache",
				"Beast",
				9,
				9,
				"Mazzranache is a strider of unusual colour, prized by anyone who can catch a glimpse.",
				true
			),
		}),
		zone("Teldrassil", "Kalimdor", {
			mob(
				1301,
				"Young Nightsaber",
				"Beast",
				1,
				3,
				"Young nightsabers practice their pounce on leaves and moths in the violet shadows."
			),
			mob(
				1302,
				"Mature Nightsaber",
				"Beast",
				4,
				6,
				"Mature nightsabers patrol the roots of the great tree in patient pairs."
			),
			mob(
				1303,
				"Feral Nightsaber",
				"Beast",
				7,
				9,
				"A feral nightsaber's eyes catch the moonlight long before its shape is visible."
			),
			mob(
				1304,
				"Strigid Owl",
				"Beast",
				1,
				3,
				"Strigid owls nest in the high boughs and turn their heads to follow every sound."
			),
			mob(
				1305,
				"Strigid Screecher",
				"Beast",
				4,
				6,
				"The screecher's cry rolls through Teldrassil's twilight and warns the forest of strangers."
			),
			mob(
				1306,
				"Strigid Hunter",
				"Beast",
				7,
				9,
				"Strigid hunters glide between branches without a whisper of wing."
			),
			mob(
				1307,
				"Webwood Spider",
				"Beast",
				1,
				3,
				"Webwood spiders spin fine webs between the roots and wait at the centre."
			),
			mob(
				1308,
				"Webwood Venomfang",
				"Beast",
				4,
				6,
				"Venomfangs wrap their prey in silk and leave it hanging until the poison has done its work."
			),
			mob(
				1309,
				"Webwood Lurker",
				"Beast",
				7,
				9,
				"Lurkers drop from the canopy on threads too fine to see in the dusk."
			),
			mob(
				1310,
				"Grell",
				"Demon",
				3,
				5,
				"Grell flit through the branches in giggling knots, more mischievous than malevolent."
			),
			mob(
				1311,
				"Grellkin",
				"Demon",
				5,
				7,
				"Grellkin hoard stolen trinkets in hollow stumps and shriek at anyone who finds them."
			),
			mob(
				1312,
				"Gnarlpine Warrior",
				"Humanoid",
				4,
				6,
				"Gnarlpine warriors guard the furbolg paths with knotty clubs and old grudges."
			),
			mob(
				1313,
				"Gnarlpine Shaman",
				"Humanoid",
				5,
				7,
				"The Gnarlpine shamans read the wind in the leaves and speak of a sickness in the tree."
			),
			mob(
				1314,
				"Gnarlpine Mystic",
				"Humanoid",
				7,
				9,
				"Mystics daub their fur with sap and call on spirits older than the night elf camps."
			),
			mob(
				1315,
				"Gnarlpine Pathfinder",
				"Humanoid",
				8,
				10,
				"Pathfinders know every deer trail on the tree and set ambushes where the roots narrow."
			),
			mob(
				1316,
				"Ursal the Mauler",
				"Humanoid",
				10,
				10,
				"Ursal the Mauler is a scarred furbolg whose name is spoken quietly in Dolanaar.",
				true
			),
			mob(
				1317,
				"Lord Melenas",
				"Humanoid",
				10,
				10,
				"Lord Melenas rules a gnarlpine camp and keeps a hoard of stolen elven silver.",
				true
			),
		}),
		zone("Elwynn Forest", "Eastern Kingdoms", {
			mob(
				1401,
				"Young Wolf",
				"Beast",
				1,
				2,
				"Young wolves nose through the ferns near the roads and are more curious than dangerous."
			),
			mob(
				1402,
				"Timber Wolf",
				"Beast",
				3,
				5,
				"Timber wolves hunt the edges of Elwynn's woods in small, wary packs."
			),
			mob(
				1403,
				"Starving Timber Wolf",
				"Beast",
				5,
				7,
				"A starving timber wolf has lost its fear of people and its patience with their flocks."
			),
			mob(
				1404,
				"Kobold Vermin",
				"Humanoid",
				1,
				3,
				"Kobold vermin scurry between candlelit burrows and shriek at every footstep."
			),
			mob(
				1405,
				"Kobold Worker",
				"Humanoid",
				4,
				6,
				"Kobold workers haul ore through the tunnels and guard their candles fiercely."
			),
			mob(
				1406,
				"Kobold Laborer",
				"Humanoid",
				7,
				9,
				"Laborers are the strongest of the tunnel folk and the first to swing a pick in a fight."
			),
			mob(
				1407,
				"Defias Thug",
				"Humanoid",
				3,
				5,
				"Defias thugs loiter near the vineyards and demand a toll from travelers who look soft."
			),
			mob(
				1408,
				"Defias Pillager",
				"Humanoid",
				6,
				8,
				"Pillagers work in twos, one to watch the road and one to carry the loot."
			),
			mob(
				1409,
				"Defias Looter",
				"Humanoid",
				7,
				9,
				"A looter knows every farmhouse in the valley and which windows are left open."
			),
			mob(
				1410,
				"Riverpaw Gnoll",
				"Humanoid",
				3,
				5,
				"Riverpaw gnolls camp along the stream and quarrel endlessly over food."
			),
			mob(
				1411,
				"Riverpaw Mongrel",
				"Humanoid",
				5,
				7,
				"Mongrels are the scrappers of the pack, quick to snarl and quicker to run."
			),
			mob(
				1412,
				"Riverpaw Brute",
				"Humanoid",
				7,
				9,
				"A brute's size keeps the lesser gnolls in line and its temper keeps them at a distance."
			),
			mob(
				1413,
				"Murloc Forager",
				"Humanoid",
				4,
				6,
				"Murloc foragers wade the shallows with nets, gurgling to one another in the reeds."
			),
			mob(
				1414,
				"Murloc Scout",
				"Humanoid",
				6,
				8,
				"Scouts creep along the riverbank and vanish into the water at the first sign of trouble."
			),
			mob(
				1415,
				"Murloc Tidecaller",
				"Humanoid",
				8,
				10,
				"Tidecallers chant at the water's edge and seem to hear an answer from the depths."
			),
			mob(
				1416,
				"Goldtooth",
				"Humanoid",
				6,
				6,
				"Goldtooth is a kobold with a taste for shine and a burrow full of stolen candles."
			),
			mob(
				1417,
				"Mother Fang",
				"Beast",
				10,
				10,
				"Mother Fang keeps a great web in the eastern woods and broods over a legion of young.",
				true
			),
			mob(
				1418,
				"Fedfennel",
				"Humanoid",
				9,
				9,
				"Fedfennel is a Riverpaw gnoll who has survived every attempt to clear the camp.",
				true
			),
		}),
		zone("Westfall", "Eastern Kingdoms", {
			mob(
				1501,
				"Goretusk",
				"Beast",
				11,
				13,
				"Goretusks root through the ruined fields and pay little mind to the scarecrows."
			),
			mob(
				1502,
				"Young Goretusk",
				"Beast",
				10,
				12,
				"Young goretusks stay close to the sow and scatter at the first loud noise."
			),
			mob(
				1503,
				"Fleshripper",
				"Beast",
				12,
				14,
				"Fleshrippers circle above the fields on ragged wings, waiting for something to stop moving."
			),
			mob(
				1504,
				"Greater Fleshripper",
				"Beast",
				15,
				17,
				"The greater fleshripper is large enough to carry off a sheep and bold enough to try."
			),
			mob(
				1505,
				"Harvest Watcher",
				"Mechanical",
				11,
				13,
				"Harvest watchers still patrol the fields, though their orders died with the farm."
			),
			mob(
				1506,
				"Harvest Golem",
				"Mechanical",
				13,
				15,
				"Harvest golems work the dead fields with a patience no living farmhand could match."
			),
			mob(
				1507,
				"Harvest Reaper",
				"Mechanical",
				16,
				18,
				"A reaper's blades are meant for wheat, but the machine no longer tells the difference."
			),
			mob(
				1508,
				"Defias Highwayman",
				"Humanoid",
				12,
				14,
				"Highwaymen watch the roads from the ruins and take what the farms have left."
			),
			mob(
				1509,
				"Defias Trapper",
				"Humanoid",
				13,
				15,
				"Trappers set snares along the fences and know how to wait without being seen."
			),
			mob(
				1510,
				"Defias Smuggler",
				"Humanoid",
				14,
				16,
				"Smugglers move crates through the hills at night and sell to anyone with coin."
			),
			mob(
				1511,
				"Defias Blackguard",
				"Humanoid",
				17,
				19,
				"A blackguard is the Brotherhood's muscle, armored in scavenged plate and old confidence."
			),
			mob(
				1512,
				"Murloc Tidehunter",
				"Humanoid",
				10,
				12,
				"Tidehunters patrol the coast in twos and drag their catches back to the shallows."
			),
			mob(
				1513,
				"Murloc Oracle",
				"Humanoid",
				13,
				15,
				"Oracles mutter at the waves and claim to read the tide's intentions in the foam."
			),
			mob(
				1514,
				"Coyote",
				"Beast",
				11,
				13,
				"Coyotes slip through the broken fences at dusk and sing to one another across the fields."
			),
			mob(
				1515,
				"Murloc Coastrunner",
				"Humanoid",
				12,
				14,
				"Coastrunners patrol the western shore and retreat into the surf when the odds turn."
			),
			mob(
				1516,
				"Leprithus",
				"Mechanical",
				14,
				14,
				"Leprithus is a harvest golem whose chassis has outlasted every farmer who owned it.",
				true
			),
			mob(
				1517,
				"Foe Reaper 4000",
				"Mechanical",
				18,
				18,
				"The Foe Reaper was built to protect a farm and now protects it from everything living.",
				true
			),
			mob(
				1518,
				"Slark",
				"Humanoid",
				15,
				15,
				"Slark is a murloc of unusual size whose croak carries over the whole western shore.",
				true
			),
			mob(
				1519,
				"Master Digger",
				"Humanoid",
				12,
				12,
				"Master Digger runs the kobold tunnels beneath Westfall and keeps the best candles for himself.",
				true
			),
		}),
		zone("Redridge Mountains", "Eastern Kingdoms", {
			mob(
				1601,
				"Redridge Mongrel",
				"Humanoid",
				15,
				17,
				"Redridge mongrels prowl the passes and fight over every traveler's pack."
			),
			mob(
				1602,
				"Redridge Brute",
				"Humanoid",
				17,
				19,
				"Brutes carry crude axes and a confidence borrowed from the size of their pack."
			),
			mob(
				1603,
				"Redridge Mystic",
				"Humanoid",
				18,
				20,
				"Mystics daub their fur with ash and speak to something in the mountain's hollows."
			),
			mob(
				1604,
				"Redridge Basher",
				"Humanoid",
				19,
				21,
				"The bashers are the pack's shock troops, sent first and expected to win."
			),
			mob(
				1605,
				"Tarantula",
				"Beast",
				15,
				17,
				"Tarantulas nest in the dry rocks and leave silk trails across the road at night."
			),
			mob(
				1606,
				"Mountain Buzzard",
				"Beast",
				15,
				17,
				"Mountain buzzards ride the updrafts and drop like stones when something small moves below."
			),
			mob(
				1607,
				"Dire Condor",
				"Beast",
				18,
				20,
				"A dire condor's wingspan is enough to block the sun for a heartbeat before it strikes."
			),
			mob(
				1608,
				"Great Goretusk",
				"Beast",
				17,
				19,
				"The great goretusk is a surly old boar that has learned to hate the sound of boots."
			),
			mob(
				1609,
				"Blackrock Champion",
				"Humanoid",
				19,
				21,
				"Blackrock champions hold the bridge and answer every challenge with a bellow."
			),
			mob(
				1610,
				"Blackrock Shadowcaster",
				"Humanoid",
				20,
				22,
				"Shadowcasters call on the dark beneath the mountain and speak of a coming master."
			),
			mob(
				1611,
				"Blackrock Outrunner",
				"Humanoid",
				18,
				20,
				"Outrunners carry orders between the camps and know every shortcut through the rocks."
			),
			mob(
				1612,
				"Blackrock Renegade",
				"Humanoid",
				20,
				22,
				"Renegades have abandoned their clans but not their taste for a fight."
			),
			mob(
				1613,
				"Blackrock Sentry",
				"Humanoid",
				21,
				23,
				"A sentry's horn can bring the whole camp down on a careless traveler."
			),
			mob(
				1614,
				"Murloc Flesheater",
				"Humanoid",
				16,
				18,
				"Flesheaters gather at the lake's edge and grow bold when the fishing is poor."
			),
			mob(
				1615,
				"Murloc Nightcrawler",
				"Humanoid",
				18,
				20,
				"Nightcrawlers leave the water after dark and follow the smell of cooking fires."
			),
			mob(
				1616,
				"Murloc Shorestriker",
				"Humanoid",
				19,
				21,
				"Shorestrikers carry barbed spears and use the reeds as cover."
			),
			mob(
				1617,
				"Yowler",
				"Humanoid",
				19,
				19,
				"Yowler is a Redridge gnoll whose howl is said to echo back from the far peaks.",
				true
			),
			mob(
				1618,
				"Bellygrub",
				"Beast",
				24,
				24,
				"Bellygrub is a monstrous boar that has claimed the whole eastern road as its own.",
				true
			),
			mob(
				1619,
				"Zzarc' Vul",
				"Humanoid",
				22,
				22,
				"Zzarc' Vul is a rare ogre who keeps a crude camp above the lake and brooks no visitors.",
				true
			),
		}),
		zone("Loch Modan", "Eastern Kingdoms", {
			mob(
				1701,
				"Kobold Tunneler",
				"Humanoid",
				10,
				12,
				"Tunnelers dig through the hills around the dam and light every shaft with stolen candles."
			),
			mob(
				1702,
				"Kobold Geomancer",
				"Humanoid",
				13,
				15,
				"Geomancers read the rock with their palms and can bring a tunnel down in a heartbeat."
			),
			mob(
				1703,
				"Stonesplinter Trogg",
				"Humanoid",
				10,
				12,
				"Stonesplinter troggs lurk in the caves and resent every dwarf who digs nearby."
			),
			mob(
				1704,
				"Stonesplinter Seer",
				"Humanoid",
				13,
				15,
				"Seers stare into the dark and mutter about the old ones sleeping under the mountains."
			),
			mob(
				1705,
				"Stonesplinter Skullthumper",
				"Humanoid",
				16,
				18,
				"The skullthumper earns its name with a heavy club and a short temper."
			),
			mob(
				1706,
				"Stonesplinter Geomancer",
				"Humanoid",
				17,
				19,
				"Geomancers shape the cave walls and hurl sharp stones at anyone who breaks their line."
			),
			mob(
				1707,
				"Crag Boar",
				"Beast",
				10,
				12,
				"Crag boars pick their way across the rocky slopes and charge downhill without warning."
			),
			mob(
				1708,
				"Elder Crag Boar",
				"Beast",
				13,
				15,
				"An elder boar's hide is thick enough to turn a careless blade."
			),
			mob(
				1709,
				"Black Bear",
				"Beast",
				11,
				13,
				"Black bears fish the shallows of the loch and sleep away the cold months in the pines."
			),
			mob(
				1710,
				"Grizzled Bear",
				"Beast",
				14,
				16,
				"A grizzled bear has survived enough winters to know when to stand and when to run."
			),
			mob(
				1711,
				"Mountain Boar",
				"Beast",
				15,
				17,
				"Mountain boars root among the stones and leave the trail churned behind them."
			),
			mob(
				1712,
				"Mosshide Gnoll",
				"Humanoid",
				14,
				16,
				"Mosshide gnolls camp in the wet hollows and wear the loch's green mud as a badge."
			),
			mob(
				1713,
				"Mosshide Mongrel",
				"Humanoid",
				15,
				17,
				"Mongrels are the pack's foragers, always hungry and never far from a fight."
			),
			mob(
				1714,
				"Mosshide Trapper",
				"Humanoid",
				17,
				19,
				"Trappers set their snares along the deer paths and check them before dawn."
			),
			mob(
				1715,
				"Mo'grosh Ogre",
				"Humanoid",
				16,
				18,
				"Mo'grosh ogres keep to the old ruins and throw stones at anything that climbs the path."
			),
			mob(
				1716,
				"Mo'grosh Brute",
				"Humanoid",
				18,
				20,
				"A brute's laughter can be heard from the road long before it comes into view."
			),
			mob(
				1717,
				"Mo'grosh Shaman",
				"Humanoid",
				19,
				20,
				"The Mo'grosh shaman paints the ruins with symbols older than the ogre camps."
			),
			mob(
				1718,
				"Gibblewilt",
				"Humanoid",
				15,
				15,
				"Gibblewilt is a Mosshide gnoll whose name is cursed by every traveler on the northern road.",
				true
			),
			mob(
				1719,
				"Boulderheart",
				"Elemental",
				18,
				18,
				"Boulderheart is a walking stone that guards the deep hills and answers only to the earth.",
				true
			),
			mob(
				1720,
				"Boss Galgosh",
				"Humanoid",
				17,
				17,
				"Boss Galgosh rules a camp of ogres and keeps a throne made from a broken wagon.",
				true
			),
		}),
		zone("Tirisfal Glades", "Eastern Kingdoms", {
			mob(
				1801,
				"Duskbat",
				"Beast",
				1,
				3,
				"Duskbats pour from the crypts at twilight and scatter across the dead fields."
			),
			mob(
				1802,
				"Duskbat Scavenger",
				"Beast",
				4,
				6,
				"Scavengers follow the scent of old blood and roost in the eaves of ruined chapels."
			),
			mob(
				1803,
				"Vicious Duskbat",
				"Beast",
				6,
				8,
				"A vicious duskbat has grown bold enough to hunt the roads rather than the fields."
			),
			mob(
				1804,
				"Rotting Dead",
				"Undead",
				2,
				4,
				"The rotting dead rise from shallow graves and wander toward the sound of living voices."
			),
			mob(
				1805,
				"Ragged Ghoul",
				"Undead",
				4,
				6,
				"Ragged ghouls claw through the earth and drag themselves toward the nearest warmth."
			),
			mob(
				1806,
				"Ravenous Darkhound",
				"Beast",
				1,
				3,
				"Ravenous darkhounds run in lean packs through the black pines."
			),
			mob(
				1807,
				"Darkhound",
				"Beast",
				3,
				5,
				"Darkhounds are drawn to the scent of fear and hunt it across the whole glade."
			),
			mob(
				1808,
				"Scarlet Convert",
				"Humanoid",
				2,
				4,
				"Scarlet converts carry their new faith like a shield and their old doubts like a wound."
			),
			mob(
				1809,
				"Scarlet Initiate",
				"Humanoid",
				1,
				3,
				"Initiates drill in the chapel yard and dream of proving themselves to the Crusade."
			),
			mob(
				1810,
				"Scarlet Warrior",
				"Humanoid",
				4,
				6,
				"Scarlet warriors patrol the roads and see heresy in every shadow."
			),
			mob(
				1811,
				"Scarlet Missionary",
				"Humanoid",
				6,
				8,
				"Missionaries preach at the crossroads and mark the unconvinced for later."
			),
			mob(
				1812,
				"Scarlet Scout",
				"Humanoid",
				5,
				7,
				"Scouts watch the farms from the treeline and count every wagon that passes."
			),
			mob(
				1813,
				"Vile Fin Puddlejumper",
				"Humanoid",
				3,
				5,
				"Puddlejumpers splash through the shallows and snatch at anything that dangles."
			),
			mob(
				1814,
				"Vile Fin Minor Oracle",
				"Humanoid",
				5,
				7,
				"Minor oracles read the ripples and argue with the water in a bubbling tongue."
			),
			mob(
				1815,
				"Fenros",
				"Beast",
				8,
				8,
				"Fenros is a darkhound of unusual size whose howl carries across the whole glade.",
				true
			),
			mob(
				1816,
				"Morgaine the Sly",
				"Humanoid",
				7,
				7,
				"Morgaine the Sly is a Scarlet deserter who knows every hiding place in Tirisfal.",
				true
			),
			mob(
				1817,
				"Deeb",
				"Beast",
				5,
				5,
				"Deeb is a pale spider whose web stretches between two ancient gravestones.",
				true
			),
		}),
		zone("Silverpine Forest", "Eastern Kingdoms", {
			mob(
				1901,
				"Son of Arugal",
				"Humanoid",
				18,
				20,
				"The Sons of Arugal run the forest at night and answer to a hunger older than the king's law."
			),
			mob(
				1902,
				"Moonrage Glutton",
				"Humanoid",
				15,
				17,
				"Moonrage gluttons tear through the farms and leave nothing but claw marks and silence."
			),
			mob(
				1903,
				"Moonrage Darksoul",
				"Humanoid",
				17,
				19,
				"Darksouls carry the curse lightly and hunt with an awful, patient joy."
			),
			mob(
				1904,
				"Moonrage Whitescalp",
				"Humanoid",
				16,
				18,
				"Whitescalps are the pack's trackers, following a scent for miles through the pines."
			),
			mob(
				1905,
				"Moonrage Elder",
				"Humanoid",
				19,
				20,
				"An elder leads the pack by old instinct and fears nothing in the forest."
			),
			mob(
				1906,
				"Rot Hide Gnoll",
				"Humanoid",
				10,
				12,
				"Rot Hide gnolls haunt the roads and keep their distance from the worgen packs."
			),
			mob(
				1907,
				"Rot Hide Mongrel",
				"Humanoid",
				12,
				14,
				"Mongrels are the boldest of the Rot Hide and the first to test a traveler's nerve."
			),
			mob(
				1908,
				"Rot Hide Brute",
				"Humanoid",
				14,
				16,
				"Brutes drag their knuckles and guard the camps with rusted cleavers."
			),
			mob(
				1909,
				"Rot Hide Plague Weaver",
				"Humanoid",
				15,
				17,
				"Plague weavers mix poisons from the forest's mold and speak to the sickness as a friend."
			),
			mob(
				1910,
				"Rot Hide Graverobber",
				"Humanoid",
				16,
				18,
				"Graverobbers strip the old graves and trade their finds to anyone who does not ask questions."
			),
			mob(
				1911,
				"Dalaran Mage",
				"Humanoid",
				12,
				14,
				"Dalaran mages keep to the ruined towers and watch the forest through old wards."
			),
			mob(
				1912,
				"Dalaran Shield Guard",
				"Humanoid",
				14,
				16,
				"Shield guards hold the tower doors and refuse every visitor with the same flat courtesy."
			),
			mob(
				1913,
				"Dalaran Theurgist",
				"Humanoid",
				15,
				17,
				"Theurgists study the worgen curse from a distance and trust their circles to hold."
			),
			mob(
				1914,
				"Grizzled Bear",
				"Beast",
				11,
				13,
				"Grizzled bears keep to the deep woods and have little patience for lost travelers."
			),
			mob(
				1915,
				"Old Grizzlegut",
				"Beast",
				17,
				17,
				"Old Grizzlegut is a scarred bear who has outlived every hunter sent after him.",
				true
			),
			mob(
				1916,
				"Nefaru",
				"Beast",
				19,
				19,
				"Nefaru is a great dark wolf whose pack rules the forest north of the road.",
				true
			),
			mob(
				1917,
				"Gorelix the Fleshing",
				"Undead",
				16,
				16,
				"Gorelix the Fleshing wanders the graves with a patience that no living thing should have.",
				true
			),
		}),
	},
}
