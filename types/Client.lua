---@meta

-- FrameXML surfaces absent from Ketho's pinned annotations, and the fields this addon's own frames carry. Signatures
-- follow Gethe/wow-ui-source (see tools/typecheck.sh for the pinned revision). These declarations never load in the
-- client.

-- Blizzard_FrameXMLBase/Constants.lua: the party category that means an instance group.
---@type number
LE_PARTY_CATEGORY_INSTANCE = nil

-- The frame Core/MicroButton.lua builds: Blizzard's micro button template plus the state it stores on it.
---@class ForeverMicroButton : Button
---@field microButtonSpec table the spec the consumer passed to Create
---@field icon Texture the glyph drawn over the plate
---@field alert table? the template's alert overlay, hidden for a custom button

-- Texture: the bezel Art.Bezel draws over an icon, kept on the icon texture it frames.
---@class Texture
---@field Bezel? Texture

-- The classic target frame's layout, which UI/Rarity.lua reads alongside the modern TargetFrameContainer. Each is
-- absent on a client with the other layout, so every read checks for nil.
---@class TargetFrame
---@field TargetFrameTextureFrameTexture? Texture
---@field name? FontString
---@field Name? FontString
---@field healthbar? StatusBar
---@field HealthBar? StatusBar

-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua: a side tab's icon fills the tab, at `extent` (50 by default).
---@param fillToInterior boolean
---@param extent? number
function SidePanelTabButtonMixin:SetFillToInterior(fillToInterior, extent) end
