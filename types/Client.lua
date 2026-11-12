---@meta

-- FrameXML surfaces absent from Ketho's pinned annotations, and the fields this addon's own frames carry. Signatures
-- follow Gethe/wow-ui-source (see tools/typecheck.sh for the pinned revision). These declarations never load in the
-- client.

---@class FGClassColor
---@field GetRGB fun(self: FGClassColor): number, number, number
---@type table<string, FGClassColor>?
RAID_CLASS_COLORS = nil

---@class FGDataProvider
---@field entries any[]
---@param entries? any[]
---@return FGDataProvider
function CreateDataProvider(entries) end

---@class FGScrollBoxView
---@field SetElementInitializer fun(self: FGScrollBoxView, template: string, initializer: fun(button: Button, element: any))
---@field SetElementExtent fun(self: FGScrollBoxView, extent: number)
---@field SetPadding fun(self: FGScrollBoxView, ...: number)
---@return FGScrollBoxView
function CreateScrollBoxListLinearView() end

---@class FGScrollUtil
---@field InitScrollBoxListWithScrollBar fun(box: Frame, bar: any, view: FGScrollBoxView)
---@type FGScrollUtil
ScrollUtil = nil

---@class FGScrollBoxConstants
---@field RetainScrollPosition integer
---@type FGScrollBoxConstants
ScrollBoxConstants = nil

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
---@field FGFRarityFrame? Texture[] the rare frame's portrait ring, when shown
---@field FGFRarityArt? FGFRarityTargetArt
---@field FGFRaritySheenAnim? AnimationGroup
---@field FGFRarityIcon? Texture
---@field FGFRarityMarker? Texture

-- TargetFrame.xml: the classic target frame's portrait texture, drawn inside the frame chrome.
---@type Texture?
TargetFramePortrait = nil

-- Blizzard_SharedXMLBase/CvarUtil.lua: the global CVar registry is CreateFromMixins(CallbackRegistryMixin) mixed into
-- a Frame. The pinned annotations infer that assignment chain as a union, so name the object's real type; the callback
-- registration UI/Rarity.lua uses comes from CallbackRegistryMixin.
---@class FGFCVarCallbackRegistry : Frame, CallbackRegistryMixin
---@type FGFCVarCallbackRegistry
CVarCallbackRegistry = nil

-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua: a side tab's icon fills the tab, at `extent` (50 by default).
---@param fillToInterior boolean
---@param extent? number
function SidePanelTabButtonMixin:SetFillToInterior(fillToInterior, extent) end

-- Blizzard_AchievementUI/Blizzard_AchievementUI_Bootstrap.lua: loads the load-on-demand achievement UI. AlertFrames
-- calls it before its own toasts so the alert template's AchievementShield_OnLoad exists.
---@return boolean?
function AchievementFrame_LoadUI() end
