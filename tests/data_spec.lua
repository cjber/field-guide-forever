local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness({
	files = { "Locales/enUS.lua", "Data/Creatures.lua" },
})
local zones = harness.ns.Creatures.zones
local FAMILIES = {
	Beast = true,
	Humanoid = true,
	Undead = true,
	Dragonkin = true,
	Elemental = true,
	Giant = true,
	Mechanical = true,
	Critter = true,
	Demon = true,
	Aberration = true,
}
local REQUIRED = {
	"The Barrens",
	"Durotar",
	"Mulgore",
	"Teldrassil",
	"Elwynn Forest",
	"Westfall",
	"Redridge Mountains",
	"Loch Modan",
	"Tirisfal Glades",
	"Silverpine Forest",
}

assert(#zones >= #REQUIRED, "at least the ten required zones")
local foundZones = {}
local ids = {}
local rareZones = 0
for _, zone in ipairs(zones) do
	foundZones[zone.name] = true
	assert(type(zone.continent) == "string" and zone.continent ~= "", zone.name .. " has a continent")
	assert(#zone.species >= 10, zone.name .. " has at least ten species")
	local rares = 0
	for _, species in ipairs(zone.species) do
		assert(type(species.id) == "number" and species.id % 1 == 0, species.name .. " has an integer id")
		assert(not ids[species.id], "duplicate species id " .. species.id)
		ids[species.id] = true
		assert(species.zone == zone.name, species.name .. " carries its zone")
		assert(species.minLevel >= 1 and species.maxLevel <= 60, species.name .. " is within levels 1 to 60")
		assert(species.minLevel <= species.maxLevel, species.name .. " has a sane level range")
		assert(type(species.lore) == "string" and #species.lore > 0, species.name .. " has lore")
		assert(FAMILIES[species.family], species.name .. " has a known family")
		if species.rare then
			rares = rares + 1
		end
	end
	if rares > 0 then
		rareZones = rareZones + 1
	end
end

for _, name in ipairs(REQUIRED) do
	assert(foundZones[name], "missing zone " .. name)
end
assert(rareZones >= 8, "at least eight zones have a rare species")

print("data: ok")
