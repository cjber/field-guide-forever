-- Registers the ForeverCore checkout with a scenario's client before login. A scenario's own addon requires it with
-- ## Dependencies, so the loader loads core first; FOREVER_CORE names the checkout, or the sibling ../forever-core is
-- used for local runs. The packed addon's TOC loads the embedded copy from Libs/ForeverCore, so there no standalone
-- ForeverCore is registered, as for a player who has it turned off, and the embedded copy is the one checked.
local Core = {}

---@return boolean
local function Embedded()
	local file = io.open("FieldGuideForever.toc", "r")
	if not file then
		return false
	end
	local toc = file:read("*a")
	file:close()
	return toc:find("Libs\\ForeverCore\\", 1, true) ~= nil
end

---@param sim table the scenario's simulator
function Core.install(sim)
	if Embedded() then
		return
	end
	sim:addon(os.getenv("FOREVER_CORE") or "../forever-core", "ForeverCore")
end

return Core
