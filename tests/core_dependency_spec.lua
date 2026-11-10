-- Field Guide Forever requires ForeverCore. This spec covers the two places the handover is the addon's: the one-line
-- stop for a ForeverCore older than API 1, and the per-addon context Register returns.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local env, ns = harness.env, harness.ns

harness:Fire("ADDON_LOADED", "FieldGuideForever")

-- The addon registers once, and the same name returns core's one context for it.
assert(ns.core ~= nil, "the addon registered its ForeverCore services")
assert(ns.core == env.ForeverCore.Register("FieldGuideForever"), "Register is idempotent for the addon's name")
assert(type(ns.core.SafeCall) == "function", "the context carries the addon's SafeCall")
assert(type(ns.core.Report.Show) == "function", "and its own report window")

-- An older ForeverCore stops the addon's own files with one line in the error frame, never chat.
local function Require(foreverCore)
	local lines = {}
	local scratch = {
		UIErrorsFrame = {
			AddMessage = function(_, text, red, green, blue)
				lines[#lines + 1] = { text = text, red = red, green = green, blue = blue }
			end,
		},
		ForeverCore = foreverCore,
	}
	scratch._G = scratch
	setmetatable(scratch, { __index = _G })
	local addon = {}
	setfenv(assert(loadfile(here .. "/../Core/Require.lua")), scratch)("FieldGuideForever", addon)
	return addon, lines
end

local broken, lines = Require(nil)
assert(broken.broken == true, "a missing ForeverCore stops the addon")
assert(#lines == 1 and lines[1].text:find("ForeverCore", 1, true), "and says so in one error line")
local old, oldLines = Require({ API = 0 })
assert(old.broken == true and #oldLines == 1, "a ForeverCore older than API 1 stops the addon too")
local ready, readyLines = Require({ API = 1 })
assert(ready.broken == nil, "API 1 runs the addon")
assert(#readyLines == 0, "and says nothing")

print("core_dependency_spec: ok")
