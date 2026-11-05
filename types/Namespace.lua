---@meta

-- The addon namespace every TOC file receives as its second vararg, and the catalogue, saved-state and UI records that
-- pass between those files. These declarations never load in the client.

-- A creature in the catalogue, built from QuestieDB rows by Integrations/QuestieDB.lua. API.lua's copies carry only
-- the identity, level and zone fields, so the rest are optional.
---@class FGSpecies
---@field id integer NPC ID
---@field name string
---@field minLevel integer
---@field maxLevel integer
---@field family string creature type name, "Unknown" when the client has none
---@field rare boolean QuestieDB rank 2
---@field familyID? integer CreatureFamily ID
---@field creatureTypeID? integer
---@field rank? integer QuestieDB rank: 0 normal, 1 elite, 2 rare, 3 boss
---@field boss? boolean QuestieDB rank 3
---@field zoneID? integer QuestieDB's AreaTable ID
---@field spawns? table<integer, number[][]> AreaTable ID -> { x, y } points on a 0 to 100 scale
---@field zone? string the name of the zone the species is listed under
---@field lore? string

-- An open-world zone and the species listed in it.
---@class FGZone
---@field id integer AreaTable ID
---@field name string
---@field continent string
---@field species FGSpecies[]

-- A dungeon or raid map and the species whose spawns are inside it.
---@class FGInstance
---@field id integer Map ID
---@field name string
---@field instanceType integer Map.InstanceType: 1 dungeon, 2 raid
---@field species FGSpecies[]
---@field speciesById? table<integer, FGSpecies> only while Integrations/QuestieDB.lua is building the list

-- One species' saved progress for a character. The firsts are time() stamps and the zone where each happened.
---@class FGSpeciesState
---@field count integer specimens toward mastery, capped at Model.MASTERED_AT
---@field kills integer
---@field killsEstimated? boolean the kills came from a save that counted only specimens
---@field rare integer rare sightings, capped at Model.RARE_TARGET
---@field rareKills integer
---@field shiny integer capped at Model.SHINY_TARGET
---@field shinyFinds integer
---@field lastKill? number
---@field firstKill? number
---@field firstKillZone? string
---@field firstSighting? number
---@field firstSightingZone? string
---@field firstRare? number
---@field firstRareZone? string
---@field firstShiny? number
---@field firstShinyZone? string
---@field sharedKillsBaseline? integer kills already counted when an estimated save first shared (Core/Stats.lua)

-- One boss encounter's saved record. Difficulty tables are keyed by the difficulty ID as a string.
---@class FGEncounterState
---@field id integer encounter ID
---@field name string
---@field instance string
---@field kills? integer
---@field sightings? integer
---@field difficulties? table<string, integer> difficulty ID -> kills
---@field difficultyNames? table<string, string> difficulty ID -> the client's name for it
---@field firstSighting? number
---@field firstSightingDifficulty? integer
---@field firstSightingDifficultyName? string
---@field firstKill? number
---@field firstDifficulty? integer
---@field firstDifficultyName? string

-- A character's saved state: species keyed by NPC ID, encounters keyed by encounter ID as a string.
---@class FGState
---@field species table<integer, FGSpeciesState>
---@field encounters table<string, FGEncounterState>
---@field tracked? integer the NPC ID the journal tracks
---@field unseen? table<integer, true> species recorded since the journal last showed them, tagged New in the list

---@class FGOptions
---@field showUndiscovered? boolean
---@field showSightingLog? boolean
---@field statsShare? boolean
---@field microButton? boolean
---@field discoveryText? boolean announce a first kill in the explored-area line
---@field milestoneToasts? boolean show the achievement toast for rare, shiny, mastery and zone milestones

-- One shared figure a peer reported: the value and the time() it was recorded.
---@class FGStatRecord
---@field value number
---@field time number

-- FieldGuideForeverDB after Migrate.
---@class FGDB
---@field version integer
---@field chars table<string, FGState> keyed by "Name-Realm"
---@field options FGOptions
---@field sharedStats? table<string, table<string, table<string, table<string, FGStatRecord>>>> peer -> addon -> subject -> metric
---@field peerStats table<string, table<string, table>> character -> source -> Core protocol store

-- How far one variant of a species has got: common, rare or shiny.
---@class FGVariant
---@field known boolean
---@field count integer
---@field target integer

-- One line of the session's sighting log.
---@class FGSighting
---@field time number
---@field zone string
---@field species string
---@field kind string "kill", "rare", "shiny", "sighting", "boss-first", "boss-kill" or "boss-sighting"

-- A failure SafeCall caught.
---@class FGError
---@field context string
---@field message string
---@field time number

-- A record the public API's spawn queries return: one QuestieDB spawn point resolved to a uiMapID.
---@class FGSpawn
---@field speciesID integer
---@field name string
---@field rare boolean
---@field catalogued boolean
---@field minLevel integer
---@field maxLevel integer
---@field map integer uiMapID
---@field x number 0 to 1
---@field y number 0 to 1

-- Core/API.lua's spawn index, built once the catalogue is ready.
---@class FGSpawnCache
---@field species table<integer, FGSpawn[]> NPC ID -> spawns
---@field zones table<integer, FGSpawn[]> AreaTable ID -> spawns

-- Model.Sightings: the session log, newest first, with the Model functions that change it.
---@class FGSightingLog
---@field [integer] FGSighting
local FGSightingLog = {}

---@param entry FGSighting
---@return FGSighting
function FGSightingLog.Add(entry) end

---@param entry FGSighting
---@return FGSighting
function FGSightingLog.Push(entry) end

function FGSightingLog.Clear() end

---@return FGSightingLog
function FGSightingLog.List() end

-- A bar Art.Bar draws: a frame with native background art and a sized fill texture.
---@class FGBar : Frame
---@field Fill Texture
---@field SetProgress fun(self: FGBar, fraction: number)

-- A row of the creature list (UI/List.lua) and the widgets it is drawn with.
---@class FGListRow : Button
---@field Background Texture
---@field Selected Texture
---@field Hover Texture
---@field Icon Texture
---@field Name FontString
---@field Sub FontString
---@field Counter FontString
---@field Glyph FontString
---@field New FontString
---@field NewGlow Texture
---@field Bar FGBar
---@field Fill Texture
---@field species? FGSpecies
---@field entry? FGListEntry

-- The journal window (UI/Window.lua): the client's portrait frame and native chrome.
---@class FGWindowFrame : PortraitFrameTemplate, BackdropTemplate

-- A side tab of the journal window.
---@class FGTabButton : LargeSideTabButtonTemplate
---@field tooltipText string
---@field key string

-- A button UI/Window.lua makes, with its label font string.
---@class FGButton : SharedButtonSmallTemplate
---@field Label FontString

-- A row of the creature list: the species, its saved progress and the zone it is listed under.
---@class FGListEntry
---@field species FGSpecies
---@field state? FGSpeciesState
---@field zone? FGZone

-- Data/Client.lua: client tables generated from wago.tools.
---@class FGClientData
---@field build string
---@field continents table<integer, string> continent Map ID -> name
---@field zones table<integer, {name: string, continent: integer}> AreaTable ID -> name and the Map ID it is on
---@field maps table<integer, {name: string, instanceType: integer}> Map ID -> name and Map.InstanceType
---@field families table<integer, string> CreatureFamily ID -> name
---@field portraits table<integer, integer> CreatureDisplayInfo ID -> portrait texture file ID

-- Data/CreatureIcons.lua: per-NPC creature type, family and model icon, packed into one number each.
---@class FGCreatureInfo
---@field icons table<integer, string> icon index -> icon path
---@field types table<integer, string> creature type ID -> name
---@field entries table<integer, integer> NPC ID -> packed icon index, type ID and family ID
local FGCreatureInfo = {}

-- The creature type ID, family ID and model icon path for an NPC, or nil for an NPC the table does not list.
---@param npcID number?
---@return integer? typeID
---@return integer? familyID
---@return string? icon
function FGCreatureInfo.Get(npcID) end

-- Where Integrations/QuestieDB.lua has got with the catalogue.
---@alias FGCatalogueStatus "missing"|"loading"|"ok"|"unsupported"

-- UI/SettingsPage.lua, Forever Core's shared settings page.
---@class FGSettingsPageModule
---@field Register fun(name: string, build: fun(panel: Frame, page: table)): category: table?, panel: FGSettingsPanel?

-- The canvas the shared settings page builds, with the heading it adds.
---@class FGSettingsPanel : Frame
---@field title FontString

-- What Core/Settings.lua hands Core/MicroButton.lua.
---@class FGMicroButtonSpec
---@field name string
---@field atlas string
---@field icon string
---@field title string
---@field binding string
---@field subtext string
---@field slot string
---@field getSlot? fun(): string
---@field getShown fun(): boolean? anything but true hides the button
---@field onClick fun()
---@field host? table

-- Core/MicroButton.lua, Forever Core's shared micro menu button.
---@class FGMicroButtonModule
---@field Create fun(spec: FGMicroButtonSpec): Frame?
---@field Destroy fun(button: Frame?)
---@field SetShown fun(button: Frame?, shown: boolean)
---@field Refresh fun()

-- What Model.Record reports about one kill.
---@class FGRecordResult
---@field count integer
---@field kills integer
---@field rank integer
---@field previousRank integer
---@field shiny boolean
---@field rare boolean
---@field newlyDiscovered boolean
---@field firstKill boolean
---@field firstRare boolean
---@field rareKnown boolean
---@field shinyKnown boolean

---@class FGNamespace
---@field L table<string, string> English phrases are the keys; an untranslated key reads as itself
---@field ClientData FGClientData
---@field CreatureInfo FGCreatureInfo
---@field LegacyIds table<integer, string> former synthetic catalogue IDs -> creature names
---@field ready boolean true once the saved variables are migrated
---@field db? FGDB
---@field SCHEMA integer
---@field catalogueStatus? FGCatalogueStatus
---@field Zones FGZone[]
---@field Instances FGInstance[]
---@field ZoneByName table<string, FGZone> lower-case name -> zone
---@field SpeciesById table<integer, FGSpecies>
---@field SpeciesZone table<integer, FGZone> NPC ID -> the zone the species is listed under
---@field microButton? Frame the micro menu button, set by Core/MicroButton.lua
---@field Model FGModel
---@field API FGPublicAPI
---@field Stats FGStatsModule
---@field PeerStats table shared Core peer transport factories
---@field QuestieDB FGQuestieDBModule
---@field Settings FGSettingsModule
---@field SettingsPage FGSettingsPageModule
---@field MicroButton FGMicroButtonModule
---@field Art FGArt
---@field Rarity FGRarity
---@field Tooltip FGTooltipModule
---@field List FGList
---@field Detail FGDetail
---@field InstancesView FGInstancesView
---@field Window FGWindow
---@field Discovery FGDiscovery
---@field SafeCall fun(context: string, fn: function, ...: any): ok: boolean, result: any
---@field GetErrors fun(): FGError[]
---@field ClearErrors fun()
---@field BuildCatalogue fun()
---@field FindZone fun(name: string?): FGZone?
---@field CurrentZone fun(): FGZone?
---@field FindSpecies fun(name: string?, zone: FGZone?): FGSpecies?
---@field CharacterKey fun(): string
---@field Migrate fun(db: any): FGDB, boolean?
---@field GetCharacterState fun(create?: boolean): FGState?
---@field Initialize fun()
---@field OnProgress fun(fn: fun())
---@field OnRecord fun(fn: fun(species: FGSpecies, zone: FGZone, result: FGRecordResult))
---@field FireProgress fun()
---@field RecordKill fun(name: string?, npcId: integer?): table?
---@field RecordSighting fun(unit: string): boolean
---@field On fun(event: string, fn: function): boolean
---@field Readable fun(value: any): any the value, or nil when the client keeps it secret
---@field Usable fun(frame: Frame?): boolean false for nil or a forbidden frame
---@field OpenGuide fun()

---@class FGGlobal
---@field API FGPublicAPI

---@type FGGlobal
FieldGuideForever = nil

---@type table?
FieldGuideForeverDB = nil
