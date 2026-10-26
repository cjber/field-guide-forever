std = "lua51"
max_line_length = 120
exclude_files = {
	"tools/.cache/**",
	".release/**",
	".types/**",
	"types/**",
	".claude/**",
	"reference/**",
}
ignore = { "212/_.*" } -- unused arguments prefixed with _
globals = {
	"FieldGuideForever",
	"FieldGuideForeverDB",
	"SLASH_FIELDGUIDEFOREVER1",
	"SLASH_FIELDGUIDEFOREVER2",
	"SLASH_FIELDGUIDEFOREVER3",
	"SlashCmdList",
}
read_globals = {
	"LibQuestieDB",
	"QuestieDB",
	"Questie",

	"C_NamePlate",
	"C_Timer",
	"COMBATLOG_OBJECT_REACTION_HOSTILE",
	"COMBATLOG_OBJECT_TYPE_NPC",
	"CombatLogGetCurrentEventInfo",
	"CreateColor",
	"CreateFrame",
	"GameFontDisableSmall",
	"GameFontHighlight",
	"GameFontHighlightSmall",
	"GameFontNormal",
	"GameFontNormalLarge",
	"GameFontNormalSmall",
	"GameTooltip",
	"GetBuildInfo",
	"GetLocale",
	"GetInstanceInfo",
	"GetDifficultyInfo",
	"C_ChatInfo",
	"Enum",
	"IsInGuild",
	"IsInGroup",
	"IsInRaid",
	"LE_PARTY_CATEGORY_INSTANCE",
	"GetRealmName",
	"GetRealZoneText",
	"GetZoneText",
	"InCombatLockdown",
	"InterfaceOptions_AddCategory",
	"Settings",
	"UIParent",
	"UISpecialFrames",
	"UnitClass",
	"UnitGUID",
	"UnitLevel",
	"UnitIsEnemy",
	"UnitIsPlayer",
	"UnitName",
	"date",
	"geterrorhandler",
	"time",
}

-- A translation's lines are as long as its phrases.
files["Locales/*.lua"] = { max_line_length = false }
