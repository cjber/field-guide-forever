local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns
local API = harness.env.BestiaryForever and harness.env.BestiaryForever.API

assert(API, "the public API is installed")
assert(API.version >= 1, "the contract is versioned")

assert(API.Species("The Barrens") == nil, "before initialisation there is no answer")
assert(API.Progress("The Barrens") == nil, "progress is unknown before initialisation")
assert(API.Specimen(1001) == nil, "a specimen is unknown before initialisation")
assert(not API.Ready(), "not ready before the saved variables load")

harness:Fire("ADDON_LOADED", "BestiaryForever")
assert(ns.ready, "the addon initialises on its own ADDON_LOADED")
assert(harness.env.BestiaryForeverDB.version == 1, "the database is versioned")
assert(API.Ready(), "the API answers after initialisation")

local species = API.Species("The Barrens")
assert(species and #species >= 10, "the Barrens' catalogue is readable")
assert(species[1].zone == "The Barrens" and species[1].lore ~= "", "species carry their facts")

local progress = API.Progress("The Barrens")
assert(progress and progress.total == #species, "the API counts the same catalogue")
assert(progress.catalogued == 0 and progress.fraction == 0, "an empty catalogue has no progress")

ns.Model.ClearSightings()
ns.Model.SetRandom(function()
	return 1
end)
harness:Kill("Plainstrider")
local specimen = API.Specimen(1001)
assert(specimen and specimen.count == 1 and specimen.rank == 1, "a recorded kill is visible through the API")
assert(not specimen.shiny and not specimen.rare, "an ordinary kill is neither rare nor shiny")
progress = API.Progress("The Barrens")
assert(progress.catalogued == 1, "the kill catalogues the species")

for _ = 1, ns.Model.RARE_TARGET do
	harness:Kill("Dishu")
end
local rare = API.Specimen(1019)
assert(rare and rare.rareCount == ns.Model.RARE_TARGET and rare.rare, "rare sightings reach the variant target")

ns.Model.SetRandom(function()
	return 0
end)
harness:Kill("Plainstrider")
specimen = API.Specimen(1001)
assert(specimen.shiny and specimen.shinyCount == 1, "a lucky roll is visible as a shiny")

local sightings = API.Sightings()
assert(sightings and #sightings >= 1, "the session log is exposed")
assert(sightings[1].species == "Plainstrider" and sightings[1].kind == "shiny", "newest sighting first")

local unknownZone = API.Progress("Nowhere")
assert(unknownZone == nil, "an unknown zone has no answer")
assert(API.Specimen(999999) == nil, "an unknown species has no answer")

print("api: ok")
