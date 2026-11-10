-- The habitat map is a native inset: the zone's tiles fill it at their own aspect, the partial edge tiles are cropped
-- to the layer, and spawn points become legible pins. Opening the world map goes through the shared secure opener and
-- never runs in combat.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local env, ns = harness.env, harness.ns

harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")

local parent = env.CreateFrame("Frame")
local map = ns.Art.ZoneMap(parent, 174, 116)
local points = { { 0.5, 0.5 }, { 0.12, 0.88 } }
assert(ns.Art.SetZoneMap(map, 1413, points), "the Barrens art draws")

-- The 1002x668 layer's last column is 234 wide and its last row 156 tall, so they must not be placed at full tile
-- size; the frame's aspect matches the layer, so the scale is simply width over layer width.
local scale = 174 / 1002
local last = map.tiles[12]
assert(#map.tiles >= 12, "one texture per tile in the layer, then any overlays: " .. #map.tiles)
assert(
	math.abs(last:GetWidth() - 234 * scale) < 0.01 and math.abs(last:GetHeight() - 156 * scale) < 0.01,
	"the partial edge tile is cropped to the layer"
)
local _, _, _, lastX, lastY = last:GetPoint(1)
assert(math.abs(lastX - 3 * 256 * scale) < 0.01 and math.abs(lastY + 2 * 256 * scale) < 0.01, "the last tile is placed")

assert(#map.markers == 2, "one marker per habitat point")
assert(map.markers[1]:GetAtlas() == "Waypoint-MapPin-Tracked", "the marker is the client's map pin")
local markerW, markerH = map.markers[1]:GetSize()
assert(markerW == 15 and markerH == 15, "the square pin is drawn at its native 15 by 15 size")
local _, _, _, markerX, markerY = map.markers[1]:GetPoint(1)
assert(
	math.abs(markerX - 174 * 0.5) < 0.01 and math.abs(markerY + 116 * 0.5) < 0.01,
	"a marker sits at its map coordinate"
)
assert(ns.Art.SetZoneMap(map, 1413, nil), "reusing the map redraws it")
assert(not map.markers[1]:IsShown(), "reusing the map hides points the next species does not have")
assert(map.markers[1]:GetAtlas() == "Waypoint-MapPin-Tracked", "the marker keeps the client's map pin art")

-- The detail pane builds the same map inside its own inset and passes the selected species' spawns.
ns.QuestieDB.AreaMaps = function()
	return { [17] = 1413 }, {}
end
local detail = ns.Detail
detail.Create(env.CreateFrame("Frame"))
local zone = { id = 17, name = "The Barrens", continent = "Kalimdor", species = {} }
local species = {
	id = 1001,
	name = "Plainstrider",
	family = "Beast",
	minLevel = 1,
	maxLevel = 1,
	spawns = { [17] = { { 45, 66 }, { 46, 66 }, { 45, 67 } } },
}
zone.species[1] = species
local state = ns.GetCharacterState(true)
detail.Show(species, state, zone)
assert(detail.location.template == "InsetFrameTemplate", "the map keeps the native inset frame")
assert(#detail.map.markers == 1, "nearby spawns share one marker cell")
assert(detail.mapButton:IsShown() and detail.mapButton:IsEnabled(), "a mapped zone offers Open map")

-- Open map: the shared opener runs the client's restricted map function through a secure delegate, and does nothing in
-- combat. A direct call would be refused and blamed on the addon, so nothing here may reach it.
Mock.openedMap, Mock.refusedMapOpeners = nil, nil
assert(env.ForeverCore.OpenMap(1413) and Mock.openedMap == 1413, "the map opens through the secure opener")
assert(Mock.refusedMapOpeners == nil, "the addon never calls the restricted map opener directly")
Mock.openedMap, Mock.refusedMapOpeners = nil, nil
assert(env.ForeverCore.OpenMap(0) and Mock.openedMap == nil, "a zero map id opens where the player is")
assert(Mock.refusedMapOpeners == nil, "a zero map id stays secure")
env.InCombatLockdown = function()
	return true
end
Mock.openedMap, Mock.refusedMapOpeners = nil, nil
assert(not env.ForeverCore.OpenMap(1415) and Mock.openedMap == nil, "combat blocks the map")
assert(Mock.refusedMapOpeners == nil, "combat never reaches the restricted map opener")
print("map inset: ok")
