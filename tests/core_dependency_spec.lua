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
local pinFile = assert(io.open(here .. "/../tools/forever-core.txt", "r"), "tools/forever-core.txt records the pin")
local pinned = assert(pinFile:read("*a"):match("^%s*(.-)%s*$"), "tools/forever-core.txt names a pin")
pinFile:close()
assert(pin == pinned, "the TOC records the ForeverCore this addon ships")
local function Load(foreverCore, coreAddon)
	if coreAddon == nil then
		coreAddon = { loaded = true, enabled = 2 }
	end
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
				if name == 1 and coreAddon then
					if field == "X-Curse-Project-ID" then
						return "1796337"
					end
					if field == "Title" then
						return "ForeverCore"
					end
				end
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
				return coreAddon and 1 or 0
			end,
			GetAddOnInfo = function(index)
				if index == 1 and coreAddon then
					return "ForeverCore"
				end
			end,
			IsAddOnLoaded = function(index)
				return index == 1 and coreAddon and coreAddon.loaded
			end,
			GetAddOnEnableState = function(index)
				return index == 1 and coreAddon and coreAddon.enabled
			end,
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

-- A missing ForeverCore folder asks for an install in one line.
local absent, absentLines = Load(nil, false)
assert(absent.broken == true, "a missing ForeverCore folder stops the addon")
assert(#absentLines == 1, "a missing ForeverCore folder takes one error line")
assert(
	absentLines[1].text
		== (
			"Field Guide Forever needs ForeverCore. Install it from CurseForge, "
			.. "or choose Reinstall on ForeverCore in the CurseForge app."
		),
	"a missing ForeverCore folder asks for an install"
)

-- An installed but disabled ForeverCore asks for it to be enabled in one line.
local disabled, disabledLines = Load(nil, { loaded = false, enabled = 0 })
assert(disabled.broken == true, "a disabled ForeverCore stops the addon")
assert(#disabledLines == 1, "a disabled ForeverCore takes one error line")
assert(
	disabledLines[1].text == "Field Guide Forever: ForeverCore is turned off. Enable it in the AddOns list to fix this.",
	"a disabled ForeverCore asks for it to be enabled"
)

-- ForeverCore with every member this addon calls runs the addon's own files and says nothing.
local ready, readyLines = Load({ APIKit = { Hub = function() end, NotReady = function() end } })
assert(ready.broken == nil, "a ForeverCore with every member this addon calls runs the addon")
assert(#readyLines == 0, "and says nothing")

print("core_dependency_spec: ok")
