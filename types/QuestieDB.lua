---@meta

-- The parts of QuestieDB (the LibQuestieDB global, contract 2, github.com/Questie/QuestieDB) and Questie
-- (github.com/Questie/Questie) that Integrations/QuestieDB.lua reads. Both are optional dependencies,
-- so every read checks the type at runtime first.

-- An entity reader: LibQuestieDB.Npc.
---@class FGQuestieEntity
---@field GetAllIds fun(): integer[]
---@field GetAll fun(id: integer, keys: string[]): table? the fields in `keys` order; nil for an unknown ID

---@class FGQuestieSupport
---@field Get fun(moduleName: string): table? Get("ZoneDB").private holds the zone tables as Lua source

---@class FGLibQuestieDB
---@field Npc FGQuestieEntity
---@field Support FGQuestieSupport
---@field RequireContract fun(required: integer): boolean, string?

---@type FGLibQuestieDB?
LibQuestieDB = nil

---@class FGQuestieAPI
---@field RegisterOnReady fun(callback: fun())

---@class FGQuestie
---@field API? FGQuestieAPI

---@type FGQuestie?
Questie = nil
