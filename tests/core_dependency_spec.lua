-- Field Guide Forever requires ForeverCore. This spec covers the two places the handover is the addon's: the
-- per-addon context Register returns, and the feature checks Core/Require.lua makes before calling the shared warning.
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

-- Core/ForeverRequire.lua is ForeverCore's shared warning, covered by its tests/forever_require_spec.lua. Here this
-- spec checks the half that belongs to this addon: the members Core/Require.lua requires, and that it calls it once.
local pin = Mock.TocMetadata()["X-Forever-Core"]
local pinFile = assert(io.open("tools/forever-core.txt"))
local shipped = pinFile:read("*l")
pinFile:close()
assert(pin == shipped, "the TOC records the ForeverCore this addon ships")
local function Load(foreverCore)
	local lines = {}
	local scratch = {
		ForeverCore = foreverCore,
		UIErrorsFrame = {
			AddMessage = function(_, text, red, green, blue)
				lines[#lines + 1] = { text = text, red = red, green = green, blue = blue }
			end,
		},
		UnitName = function()
			return "Tester"
		end,
		C_AddOns = {
			GetAddOnMetadata = function(name, field)
				if name == "FieldGuideForever" then
					if field == "X-Forever-Core" then
						return pin
					end
					if field == "Title" then
						return "Field Guide Forever"
					end
				end
			end,
			GetNumAddOns = function()
				return 0
			end,
			GetAddOnInfo = function() end,
			IsAddOnLoaded = function() end,
			GetAddOnEnableState = function() end,
			-- The client returns the dependencies as varargs, never as a table.
			GetAddOnDependencies = function()
				return unpack({})
			end,
		},
	}
	scratch._G = scratch
	setmetatable(scratch, { __index = _G })
	local addon = {}
	setfenv(assert(loadfile(here .. "/../Core/ForeverRequire.lua")), scratch)("FieldGuideForever", addon)
	setfenv(assert(loadfile(here .. "/../Core/Require.lua")), scratch)("FieldGuideForever", addon)
	return addon, lines
end

-- ForeverCore without NotReady, which Core/API.lua calls, stops the addon with one error-frame line and no chat.
local missing, missingLines = Load({ APIKit = { Hub = function() end } })
assert(missing.broken == true, "a ForeverCore missing a member this addon calls stops it")
assert(#missingLines == 1, "and says so in one error line")
assert(
	missingLines[1].text == "Field Guide Forever could not start. Reinstall Field Guide Forever to fix this.",
	"the shared warning asks for a reinstall when no other addon can be blamed"
)

-- ForeverCore with every member this addon calls runs the addon's own files and says nothing.
local ready, readyLines = Load({ APIKit = { Hub = function() end, NotReady = function() end } })
assert(ready.broken == nil, "a ForeverCore with every member this addon calls runs the addon")
assert(#readyLines == 0, "and says nothing")

print("core_dependency_spec: ok")
