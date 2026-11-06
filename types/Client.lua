---@meta

-- FrameXML surfaces absent from Ketho's pinned annotations, and the fields this addon's own frames carry. Signatures
-- follow Gethe/wow-ui-source (see tools/typecheck.sh for the pinned revision). These declarations never load in the
-- client.

-- Blizzard_FrameXMLBase/Constants.lua: the party category that means an instance group.
---@type number
LE_PARTY_CATEGORY_INSTANCE = nil

-- The saved table a consumer hands the shared minimap button: the angle and the hide flag live in it.
---@class ForeverMinimapButtonSpec
---@field name string the frame name, unique in the addon
---@field icon string|number the addon's own content icon
---@field title string the tooltip title
---@field binding? string shown under the title, e.g. "Shift-F"
---@field subtext? string the tooltip's one line about what a click does
---@field onClick? fun(button: Frame, mouseButton: string) what a left click runs
---@field settings? table the saved table holding the angle and hide flag
---@field angleKey? string the settings key holding the angle, default "minimapButtonAngle"
---@field hiddenKey? string the settings key whose true value hides the button, default "minimapButtonHidden"
---@field getShown? fun(): boolean an addon-owned visibility rule, which wins over the hide flag
---@field host? table receives the frame as its minimapButton

-- The registry every vendored copy of Core/MinimapButton.lua shares, published by the first to load.
---@class ForeverMinimapButtonRegistry
---@field buttons ForeverMinimapButton[] every addon button, in creation order
---@type ForeverMinimapButtonRegistry?
ForeverMinimapButtons = nil

-- The frame Core/MinimapButton.lua builds: the client's minimap plate, the addon's icon and the angle on the rim.
---@class ForeverMinimapButton : Button
---@field minimapButtonSpec ForeverMinimapButtonSpec the spec the consumer passed to Create
---@field icon Texture the addon's icon drawn on the plate
---@field angle number the angle around the Minimap, in degrees
---@field dragging boolean? true while the player drags the button around the rim

---@class ForeverMinimapButtonAPI
---@field Create fun(spec: ForeverMinimapButtonSpec): ForeverMinimapButton?
---@field Destroy fun(button: ForeverMinimapButton?)
---@field Refresh fun()
---@field SetShown fun(button: ForeverMinimapButton?, shown: boolean)

-- The modern target frame's container, which UI/Rarity.lua reads for the frame art and portrait it overlays.
---@class TargetFrameContainer
---@field FrameTexture Texture
---@field Portrait? Texture

-- The classic target frame's layout, which UI/Rarity.lua reads alongside the modern TargetFrameContainer. Each is
-- absent on a client with the other layout, so every read checks for nil.
---@class TargetFrame
---@field TargetFrameContainer? TargetFrameContainer
---@field TargetFrameTextureFrameTexture? Texture
---@field name? FontString
---@field Name? FontString
---@field healthbar? StatusBar
---@field HealthBar? StatusBar
---@field manabar? StatusBar
---@field ManaBar? StatusBar
---@field powerbar? StatusBar
---@field PowerBar? StatusBar
---@field portrait? Texture
---@field Portrait? Texture
---@field FGFRarityFrame? Texture[]
---@field FGFRarityArt? FGFRarityTargetArt
---@field FGFRaritySheenAnim? AnimationGroup
---@field FGFRarityIcon? Texture
---@field FGFRarityTag? Frame
---@field FGFRarityMarker? Texture

-- TargetFrame.xml: the classic target frame's portrait texture, drawn inside the frame chrome.
---@type Texture?
TargetFramePortrait = nil

-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua: a side tab's icon fills the tab, at `extent` (50 by default).
---@param fillToInterior boolean
---@param extent? number
function SidePanelTabButtonMixin:SetFillToInterior(fillToInterior, extent) end
