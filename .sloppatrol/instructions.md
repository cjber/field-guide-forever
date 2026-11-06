# About the code

Field Guide Forever is a World of Warcraft: Forever addon in Lua 5.1. The files the TOC lists are what the game
loads; `tests/*_spec.lua` load them in that order inside a stubbed client.

- Keep every saved variable name and every global the TOC exposes unchanged.
- Generated data, `Locales/` and `tools/forever_tools/` are never edited by hand.
- Never replace a Blizzard global, hook a secure function, or write a field on a Blizzard table: it
  taints the default UI.
- Never launch the game, Battle.net, Lutris or Wine, and never use the network.

## Live roots

Nothing below is dead code, even when no Lua file calls it by name.

- The files `FieldGuideForever.toc` lists, loaded in order: `Locales/`, `Data/`, `Core/`, `UI/`.
- Members of the shared table `ns`: search every file for `ns.Name`, not only the local file. `Model.*` and
  `ns.API.*` are nested tables and need their own search.
- Keys of `DEFAULTS` in `Core/Core.lua`: `FieldGuideForeverDB` may hold data an older version wrote.
- `SLASH_FIELDGUIDEFOREVER1/2`, the `UISpecialFrames` entry and every handler passed to `RegisterEvent`,
  `SetScript` or `hooksecurefunc`: the client calls them by name.
- The public `FieldGuideForever` table in `Core/API.lua`: the versioned contract companion addons use.
- `Core/LegacyIds.lua`: migrates v1 ids, removed in the release after schema 2.

`python3 tools/repo_rules.py` holds the rules no linter covers; run it with the other checks.
