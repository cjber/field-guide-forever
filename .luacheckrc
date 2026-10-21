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
	"BestiaryForever",
	"BestiaryForeverDB",
	"SLASH_BESTIARYFOREVER1",
	"SLASH_BESTIARYFOREVER2",
	"SlashCmdList",
}
read_globals = {
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
	"UnitName",
	"date",
	"geterrorhandler",
	"time",
}

-- A translation's lines are as long as its phrases.
files["Locales/*.lua"] = { max_line_length = false }
