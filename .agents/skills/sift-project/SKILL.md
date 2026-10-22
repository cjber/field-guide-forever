---
name: sift-project
description: "Project profile for sift in Field Guide Forever: the exact quality-gate and evidence commands, live roots that must never be deleted as dead code, exclusions, conventions and risk order. Load before running sift or any code-quality, cleanup or dead-code work in this repository."
---

# sift project profile: Field Guide Forever

Field Guide Forever is a World of Warcraft: Forever addon (Interface 16001) kept as a cosmetic field journal of
the creatures a character has met. The creature catalogue is read at runtime from the player's QuestieDB Forever;
never add hand-written or vendored creature names, levels, ranks or placements. It runs inside the game's Lua 5.1 sandbox; there is no `require`: the client
loads the files `FieldGuideForever.toc` lists, in that order, and each file receives `local addonName, ns = ...`.
It ships as a zip built by the BigWigs packager (`.pkgmeta`) on a `v*` tag.

## Gate

Run in order from the repository root. All must pass before and after any audit slice.

| Step | Command | Pass means |
|---|---|---|
| Format (Lua) | `stylua --check .` | exit 0 (StyLua 2.5.2) |
| Format (Python) | `ruff format --check tools` | exit 0 |
| Lint (Lua) | `luacheck .` | `0 warnings / 0 errors`, exit 0 |
| Lint (Python) | `ruff check tools` | exit 0 |
| Tests | `for s in tests/*_spec.lua; do luajit "$s" || exit 1; done` | each prints `<name>: ok`, exit 0 |
| Screenshots fresh | `python3 tools/check_screenshots.py` | exit 0: no image older than the sources it is drawn from |
| Rendered layout | `python3 tools/visual_audit.py` | exit 0: every widget inside the frame, no overlap, no bleed |
| Changelog | `python3 tools/changelog.py --check` | exit 0 |
| Project rules | `python3 .sift/gate.py --base origin/main && python3 .sift/agents.py check` | exit 0 |

CI (`.github/workflows/ci.yml`) runs all of these. The specs are a headless harness, not the game client:
`tests/wow_mock.lua` stubs the client APIs and loads the TOC's files. What needs the client itself is a `/reload`.
The screenshots are renders from `tools/mockups.py` (wowmock, the client's own art), never captures.

## Evidence

| Concern | Command | Known false positives |
|---|---|---|
| Dead code (Lua) | `luacheck . --no-color` + the live-root searches below | a function stored on `ns` is never "unused" to luacheck: search every file for `ns.<Name>` |
| Dead code (Python) | `uvx vulture tools --min-confidence 60` | none |
| Live roots | `rg -n 'hooksecurefunc\|RegisterEvent\|SetScript\|SlashCmdList\|UISpecialFrames' -g '*.lua'` | none |
| Shared-table members | `rg -n 'ns\.[A-Z]' Core UI` | `Model.*` and `ns.API.*` are nested tables and need their own search |
| Clones | `npx -y jscpd@4 --silent --min-lines 6 --ignore "docs/**,.types/**,**/.cache/**" .` | none |
| Standards | `python3 .sift/agents.py standards` | resolves the pack pinned in AGENTS.md |

## Live roots

- `FieldGuideForever.toc` file list: loads `Locales/`, `Data/`, `Core/` and `UI/` in that order.
- `ns.*`: the shared addon table; search all files for `ns.Name`, not the local file.
- `## SavedVariables: FieldGuideForeverDB`: keys in `Core/Core.lua` `DEFAULTS` may hold data written by older versions.
- `SLASH_FIELDGUIDEFOREVER1/2` and the `UISpecialFrames` entry: called by the client by name.
- `UNIT_DIED` combat-log handler and the progress callback: the kill path writes tables only; the UI refresh runs on
  the next frame.
- The public `FieldGuideForever` API table (`Core/API.lua`) is the companion-addon contract, versioned.
- `Integrations/QuestieDB.lua` is the only runtime reader of shared creature data; it reports `ok`, `missing`,
  `unsupported` or `loading` and never builds the index inside a call.
- `Core/LegacyIds.lua` migrates v1 synthetic ids by exact name and must be removed in the release after schema 2.
- Personal progress (counts, rare confirmations, shinies) lives in SavedVariables; shared rarity classification
  depends only on the NPC id and catalogue fields, never on progress.

## Zones

| Path | Zone | Reason |
|---|---|---|
| `Data/Client.lua` | data | generated client constants from pinned wago.tools DB2; never hand-edited |
| `Locales/enUS.lua` | data | every player-visible phrase, keyed by the English text |
| `tools/` | script | mock renderer, screenshot and layout checks, CI helpers; not shipped |
| `tests/` | test | headless LuaJIT harness |
| `docs/`, `reference/`, `scratch/` | docs | screenshots and reference material; not shipped |
| `.github/`, `.pkgmeta`, `.luacheckrc`, `.luarc.json`, `stylua.toml`, `.styluaignore`, `.gitignore` | config | |
| `README.md`, `CHANGELOG.md`, `AGENTS.md`, `.agents/`, `.sift/` | docs | |

## Conventions

- Tabs, 120 columns, double quotes (StyLua). `---@type` annotations; namespaces through `local _, ns = ...`.
- Keep `Core/Model.lua` pure: no WoW API, no I/O, no globals beyond `ns.Model`.
- The combat-log handler never touches a frame.
- `L["whole sentence"]` is the only source of player-visible text in `UI/`.
- Comments explain *why* (client quirks, mock geometry), not what.
- A visual fix lands in the renderer's shared constants and is re-rendered, never hand-edited into a PNG.
