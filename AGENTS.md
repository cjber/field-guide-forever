# AGENTS.md

Field Guide Forever targets the WoW: Forever client (Interface 16001). It keeps a cosmetic journal of creatures a character has encountered, with local progress and shared catalogue facts. It never grants player power, changes combat, or calls protected functions.

## Commands

```sh
stylua --check .
luacheck .
for spec in tests/*_spec.lua; do luajit "$spec" || exit 1; done
uvx ruff@0.16.8 check tools && uvx ruff@0.16.8 format --check tools
python3 tools/check_generated.py
python3 tools/check_core_shared.py
python3 tools/visual_audit.py
python3 tools/check_screenshots.py
python3 tools/changelog.py --check
python3 .sift/gate.py --base origin/main && python3 .sift/agents.py check
```

Specs are Lua 5.1 scripts run with LuaJIT through `tests/wow_mock.lua`. `FOREVER_CORE=/path/to/forever-core python3 tools/mockups.py` renders the README scenes from WoW client assets and a disposable fixture extracted from the pinned QuestieDB Forever release. The fixture lives only in an ignored cache directory under `tools/`.

`tools/` holds the development tooling, which `.pkgmeta` keeps out of the package: `tools/mockups.py` uses the
shared renderer in the sibling `forever-core` checkout (`FOREVER_CORE` overrides its location) to render
`docs/screenshots/` against the pinned client build, `tools/check_screenshots.py` fails when an image is
older than the sources it is drawn from (`--record` after a render), `tools/changelog.py` prints or checks a
release's entry, `tools/check_package.py` checks what the packager built, and `tools/release_check.py` gates the
release on a green full CI run. `tools/check_core_shared.py` is the Field Guide side of the suite's core drift gate: it
checks this repo's vendored copies against public forever-core main, and `.github/workflows/core-shared-drift.yml`
runs it on a schedule.
`tools/visual_audit.py` reads the `docs/screenshots/layout.json` manifest `tools/mockups.py` writes and fails when a widget leaves the window
frame, when two controls overlap or sit closer than 8 units apart, or when the rendered button art is not where the
manifest says it is. A layout bug is fixed in the renderer's shared constants (and in `UI/Window.lua` if the addon
agrees), then re-rendered; never by editing a PNG.

Before handing off any README or mockup change, open every screenshot the README references and inspect the rendered
images directly at full resolution, and step through the frames of `docs/screenshots/demo.gif`. Check for overlapping text or controls,
widgets or markers clipped at a frame or card edge, content drawn outside its panel, misaligned rows, and truncated
labels. A green `tools/check_screenshots.py` and `tools/visual_audit.py` prove freshness and geometry only; they do not prove the
picture looks right, so a visual defect found by eye is fixed in the renderer and re-rendered.

## Layout and data sources

- `FieldGuideForever.toc` is the client's runtime file list and load order.
- `Locales/enUS.lua` contains every player-visible phrase; UI code uses `L["whole sentence"]`.
- `Integrations/QuestieDB.lua` is the only runtime reader of QuestieDB. It builds the catalogue from the installed Forever API and reports `ok`, `missing`, `unsupported`, or `loading`.
- Creature names, levels, ranks, and spawn placement are never hand-written or vendored. The old hand-maintained catalogue must not return.
- `Data/Client.lua` is generated from pinned wago.tools DB2 exports by `tools/gen_zones.py`. It contains client constants only. `tools/check_generated.py` verifies the committed output against the pinned inputs.
- `Core/LegacyIds.lua` is a one-release migration map from old synthetic ids to names. It is only used to re-key existing records after QuestieDB loads; remove it in the release after schema 2.
- `Core/Model.lua` contains pure state arithmetic and variant classification. It has no WoW API, I/O, or globals beyond `ns.Model`.
- `Core/Core.lua` owns SavedVariables, character identity, catalogue lookup, combat-log recording, progress callbacks, and slash commands. Event handlers use `Core/SafeCall.lua`.
- `Core/API.lua` is the versioned addon-to-addon contract. It returns nil until saved state and catalogue data are ready.
- `Core/Settings.lua` registers options. `UI/Art.lua` owns frame helpers and palette; `UI/Window.lua` owns the shell and selection; other files in `UI/` own focused views.
- `tests/` contains the mock client and model, data, rarity, and API specs. `docs/screenshots/` contains the README gallery; neither ships in the addon package.

## Rules

- Runtime code targets Lua 5.1. Keep new globals limited to SavedVariables, the public API, and client-required slash globals.
- Keep `Core/Model.lua` pure and inject random sources in tests.
- The combat log writes SavedVariables and schedules refresh work; it never touches UI frames.
- Saved progress is character-local. Shared rarity classification depends only on stable QuestieDB NPC ids and shared rank fields, never on personal progress.
- Match creature names case-insensitively only when resolving localized combat-log names or migrating old records; never use personal progress to classify catalogue rarity.
- Keep SavedVariables flat and serialisable. Do not persist frames, functions, userdata, or the session sighting log.
- Use tabs, annotations, `local addonName, ns = ...`, the established palette, and Blizzard fonts. Add `read_globals` to `.luacheckrc` only for actual client APIs.
- Every user-facing feature has a mocked scene and README screenshot until the addon is published.
- Do not edit `.pkgmeta` to include development-only tools, tests, or screenshots.

## Extra rules from the layout audit round

- Never merge a change to `UI/` that leaves `python3 tools/visual_audit.py` red: read the rendered images, not just
  the diff.
- Do not edit `.luacheckrc` to hide a real warning. Add a `read_globals` entry only for a genuine WoW API global.
- Load `.agents/skills/sift-project/SKILL.md` before cleanup, dead-code or refactoring work.

## Release flow

Keep changes under an appropriate `CHANGELOG.md` version heading, run the full gate, and check the packaged TOC contents before releasing. The BigWigs packager reads `.pkgmeta`, substitutes the release version in the TOC, and publishes the changelog entry as release notes.
