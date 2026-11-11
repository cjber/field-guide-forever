local _, ns = ...

-- The game refuses to load this addon when ForeverCore is absent (## Dependencies), but an older ForeverCore still
-- loads. ForeverCore's interface version stays at 1 while it adds members, so a core is out of date when a member this
-- addon calls is missing, never because of a version comparison. This addon builds its own API on the API kit's Hub
-- and NotReady, which arrived after API 1, so a core without them stops the addon's own files here. The shared warning
-- in Core/ForeverRequire.lua shows one line on screen, never a chat message, and names the addon to update.
local ready = ForeverCore ~= nil
	and type(ForeverCore.APIKit) == "table"
	and type(ForeverCore.APIKit.Hub) == "function"
	and type(ForeverCore.APIKit.NotReady) == "function"

ns.ForeverRequire(ready)
