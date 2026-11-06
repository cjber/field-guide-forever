---@meta

-- The shared tracker contract. Forever Core's tracker files (UI/Tracker*.lua) are vendored byte for byte from
-- cjber/forever-core, whose types/Forever.lua declares these same classes: a consumer keeps its own copy so the
-- vendored files typecheck here. These declarations never load in the client.

---@class ForeverTrackerSettings
---@field attached boolean the column follows the native quest tracker
---@field locked? boolean the Lock switch, which suppresses the grip's drag
---@field scale? number the player's tracker scale, 0.5 to 2
---@field x? number the detached position, from UIParent's top left corner
---@field y? number

---@class ForeverTrackerGrip
---@field Show fun(value: boolean)
---@field SetLabel fun(value: boolean)

---@class ForeverTrackerHostAPI
---@field Attach fun(module: Frame)
---@field IsAttached fun(module: Frame?): boolean
---@field IsLocked fun(): boolean
---@field SetLocked fun(value: boolean)
---@field IsAttachedToQuestTracker fun(): boolean
---@field SetAttached fun(value: boolean)
---@field OnAttachmentChanged fun(callback: fun(attached: boolean))
---@field SavePosition fun(x: number, y: number)
---@field Debug fun(): string

---@class ForeverTrackerOrderAPI
---@field Sort fun(modules: ForeverTrackerModule[])

---@class ForeverTrackerNamespace
---@field ContextMenu? fun(owner: Frame, generator: fun(owner: Frame, root: any)): any
---@field SafeCall fun(label: string, fn: function, ...: any): boolean, ...any
---@field L table<string, string>
---@field TrackerHost? ForeverTrackerHostAPI
---@field TrackerLock? table
---@field TrackerOrder? ForeverTrackerOrderAPI
---@field TrackerQuestie? ForeverTrackerQuestie Questie's quest list, from UI/TrackerQuestie.lua
---@field TrackerEqot? ForeverTrackerEqot EQOT's quest list, from UI/TrackerEqot.lua
---@field TrackerHostSettings? fun(): ForeverTrackerSettings
---@field Defaults? ForeverTrackerSettings

-- The column the first-loaded Forever addon publishes, adopted by every later one.
---@type ForeverTrackerHostAPI?
ForeverTrackerHost = nil

-- The section FGF hands the shared column: Blizzard's ObjectiveTrackerModuleTemplate with UI/Tracker.lua's layout.
---@class FGTrackerModule : Frame, ObjectiveTrackerModuleTemplate
---@field uiOrder? number
---@field parentContainer? Frame
---@field headerText? string
---@field GetBlock fun(self: FGTrackerModule, id: number): FGTrackerBlock
---@field LayoutBlock fun(self: FGTrackerModule, block: FGTrackerBlock): boolean
---@field LayoutContents fun(self: FGTrackerModule)
---@field MarkDirty fun(self: FGTrackerModule)

-- One species' block in that section: a header line and its objective lines.
---@class FGTrackerBlock
---@field SetHeader fun(self: FGTrackerBlock, text: string)
---@field AddObjective fun(self: FGTrackerBlock, key: number, text: string)
