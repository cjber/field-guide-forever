# AGENTS.md

Field Guide Forever targets the WoW: Forever client (Interface 16001). It keeps a cosmetic journal of creatures a character has encountered, with local progress and shared catalogue facts. It never grants player power, changes combat, or calls protected functions.

It requires ForeverCore (`## Dependencies: ForeverCore`), the standalone addon that owns the shared tracker column, report window, error journal and debug log, the minimap button, the quest log side tabs, the settings-page chrome, the family page and the map canvas. CurseForge and Wago install ForeverCore with it through `.pkgmeta`'s `required-dependencies`; nothing shared is vendored here.

The shared suite standards follow forever-core `main`. For UI work, read the [wow-retail-ui-style skill](https://github.com/cjber/forever-core/blob/main/.agents/skills/wow-retail-ui-style/SKILL.md), [asset registry](https://github.com/cjber/forever-core/blob/main/docs/asset-registry.md), and [asset audit](https://github.com/cjber/forever-core/blob/main/docs/asset-audit.md) before changing layouts or assets. Use native Blizzard templates and approved atlas textures, and check the blacklist even when an asset matches a broad native prefix.

## Standards

- `wow-forever-addon`: https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-forever-addon (UI look,
  icon, README and store page, CI and release requirements shared by every WoW: Forever addon)
- `repo-standards`: the RS-* requirements every cjber repo meets (repo, Actions and security settings, rulesets, CI hardening, community files), a skill in cjber/skills whose `audit.py` checks this repo

## Commands

```sh
stylua --check .
luacheck .
FOREVER_CORE=../forever-core bash tools/typecheck.sh   # TOC/XML load graph, secret-value lint and LuaLS 3.19.1, which must report nothing
for spec in tests/*_spec.lua; do FOREVER_CORE=../forever-core luajit "$spec" || exit 1; done
uvx ruff@0.16.8 check tools && uvx ruff@0.16.8 format --check tools
python3 tools/check_generated.py
python3 tools/forever_tools/credits.py --check   # Data/Credits.lua and both thanks blocks are current (WFA-31)
python3 tools/check_core_shared.py
python3 tools/check_api_docs.py # docs/api.md names every published API function and its minor
python3 tools/check_family.py
python3 tools/visual_audit.py
python3 tools/check_screenshots.py
python3 tools/changelog.py --check
python3 tools/deadcode.py --check
python3 tools/check_menu_scroll.py # menus built from a list scroll (WFA-36); CI runs it in core-shared
python3 tools/repo_rules.py # rules no linter covers; CI runs it in project-rules
```

Specs are Lua 5.1 scripts run with LuaJIT through `tests/wow_mock.lua`. `FOREVER_CORE=/path/to/forever-core python3 tools/mockups.py` renders the README scenes from WoW client assets and a disposable fixture extracted from the pinned QuestieDB Forever release. The fixture lives only in an ignored cache directory under `tools/`.

`FOREVER_CORE` names the cjber/forever-core checkout the specs load, defaulting to the sibling `../forever-core`.
`tools/forever-core.txt` holds the git ref CI checks out for them; it is a branch while this addon adopts the
dependency and becomes `v1.0.0` at release.

`tools/` holds the development tooling, which `.pkgmeta` keeps out of the package: `tools/mockups.py` uses the
shared renderer in the sibling `forever-core` checkout (`FOREVER_CORE` overrides its location) to render
`docs/screenshots/` against the pinned client build, `tools/check_screenshots.py` fails when an image is
older than the sources it is drawn from (`--record` after a render), `tools/changelog.py` prints or checks a
release's entry, `tools/check_package.py` checks what the packager built, and `tools/release_check.py` gates the
release on a green full CI run. `tools/check_core_shared.py` is the Field Guide side of the suite's core drift gate: it
checks this repo's vendored development tooling against public forever-core main, and
`.github/workflows/core-shared-drift.yml` runs it on a schedule. Runtime files are ForeverCore's alone. `tools/typecheck.sh` verifies the vendored `tools/forever_tools/` (copied byte for byte from
forever-core: refresh it only with `python3 tools/forever_tools/sync.py update --source <forever-core checkout>`),
checks that the TOC/XML load graph reaches every runtime Lua file (`tools/typecheck_coverage.py`), then runs LuaLS
over every TOC-loaded file against the pinned WoW API and FrameXML annotations. CI runs the gate in the jobs
`deadcode`, `check`, `python`, `typecheck`, `generated-data`, `project-rules` (changelog and `tools/repo_rules.py`),
`workflows`, `secrets` and `package`, each on every pull request.
`tools/visual_audit.py` reads the `docs/screenshots/layout.json` manifest `tools/mockups.py` writes and fails when a widget leaves the window
frame, when two controls overlap or sit closer than 8 units apart, or when the rendered button art is not where the
manifest says it is. Runtime anchors and native template behavior are the source of truth. Fix the runtime producer and
matching renderer together, then re-render; never fix only a PNG or silently diverge the mock from the addon.

`tools/forever_sim/` is forever-core's client simulator, vendored the same way (`python3 tools/forever_sim/sync.py check`, `update --source <checkout>`). `luajit tools/forever_sim/run.lua` runs the scenarios in `tests/sim` under the client's real Blizzard UI source, fetched once with `python3 tools/forever_sim/fetch.py`; `tests/sim/exercise_scenario.lua` runs every slash command, the world map, combat and a `/reload` through `sim:exercise()`.

Before handing off any README or mockup change, open every screenshot the README references and inspect the rendered
images directly at full resolution, and step through the frames of `docs/screenshots/demo.gif`. Check for overlapping text or controls,
widgets or markers clipped at a frame or card edge, content drawn outside its panel, misaligned rows, and truncated
labels. A green `tools/check_screenshots.py` and `tools/visual_audit.py` prove freshness and geometry only; they do not prove the
picture looks right, so trace a visible defect to its runtime or renderer producer, correct it there and regenerate matching renders.

## Layout and data sources

- `FieldGuideForever.toc` is the client's runtime file list and load order.
- `Locales/enUS.lua` contains every player-visible phrase; UI code uses `L["whole sentence"]`.
- `Integrations/QuestieDB.lua` is the only runtime reader of QuestieDB. It builds the catalogue from the installed Forever API and reports `ok`, `missing`, `unsupported`, or `loading`.
- Creature names, levels, ranks, and spawn placement are never hand-written or vendored. The old hand-maintained catalogue must not return.
- `Data/Client.lua` is generated from pinned wago.tools DB2 exports by `tools/gen_zones.py`. It contains client constants only. `tools/check_generated.py` verifies the committed output against the pinned inputs.
- `BUILD` in `tools/gen_zones.py` is the client data pin: `tools/check_generated.py` and `tests/data_spec.lua` read it. Screenshot tools use the separate reviewed UI-art pin in `tools/ui_art.py`, covered by the screenshot freshness digest and matching Core's asset registry. The daily `.github/workflows/refresh-data.yml` moves it to the newest Forever build on wago.tools, regenerates `Data/Client.lua` and opens a data PR.
- `types/` holds LuaLS declarations for the namespace and for client globals the pinned annotations lack. It is never loaded by the TOC or shipped.
- `Core/LegacyIds.lua` is a one-release migration map from old synthetic ids to names. It is only used to re-key existing records after QuestieDB loads; remove it in the release after schema 2.
- `Core/Model.lua` contains pure state arithmetic and variant classification. It has no WoW API, I/O, or globals beyond `ns.Model`.
- `Core/Require.lua` is the API floor: an installed ForeverCore older than API 1 stops the addon's own files with one line in `UIErrorsFrame`. `Core/Core.lua` owns SavedVariables, character identity, catalogue lookup, kill and sighting recording, progress callbacks, and slash commands. `Core/Kills.lua` detects kills from the signals the client lets addons read (target and nameplate deaths, rare map markers; the combat log only where a client still allows it) and counts each death once. `Core/Secret.lua` holds `ns.Readable`, through which every possibly secret value (unit GUIDs and names) is read. Event handlers use `ns.core.SafeCall`.
- `Core/API.lua` is the versioned addon-to-addon contract. It returns nil until saved state and catalogue data are ready.
- `Core/Settings.lua` registers options. `UI/Art.lua` owns frame helpers and palette; `UI/Window.lua` owns the shell and selection; other files in `UI/` own focused views. `UI/Tracker.lua` supplies one section to `ForeverCore.TrackerHost` and offers the addon's old `trackerHost` table to it once.
- `tests/` contains the mock client and model, data, rarity, and API specs. `docs/screenshots/` holds every rendered scene and `docs/gallery.md`, written by `tools/mockups.py`, lists them; README and `docs/curseforge.md` (the store description) pick their headline images by hand. None of these ship in the addon package.
- `media/icon.svg` is the family icon (WFA-7); `python3 <forever-core>/.agents/skills/wow-forever-addon/render_icon.py` renders `media/icon-400.png` (README and store logo) and `media/Icon.tga` (the TOC icon).

## Rules

- Runtime code targets Lua 5.1. Keep new globals limited to SavedVariables, the public API, and client-required slash globals.
- Keep `Core/Model.lua` pure and inject random sources in tests.
- Kill detection writes SavedVariables and schedules refresh work; it never touches UI frames.
- Saved progress is character-local. Shared rarity classification depends only on stable QuestieDB NPC ids and shared rank fields, never on personal progress.
- Match creature names case-insensitively only when resolving localized creature names from a kill or sighting, or migrating old records; never use personal progress to classify catalogue rarity.
- Keep SavedVariables flat and serialisable. Do not persist frames, functions, userdata, or the session sighting log.
- Use tabs, annotations, `local addonName, ns = ...`, the established palette, and Blizzard fonts. Add `read_globals` to `.luacheckrc` only for actual client APIs.
- Every user-facing feature has a mocked scene listed in `docs/gallery.md`.
- Do not edit `.pkgmeta` to include development-only tools, tests, or screenshots.
- Credit players as every Forever addon does (WFA-33 in forever-core's `wow-forever-addon` skill): a fix for a reported
  bug or a feature someone asked for ends its changelog bullet "thanks to X for the report" (or "for the idea") and adds
  their row to THIRD_PARTY.md's `## Ideas and contributors`, by the handle they posted under. The addons' author,
  cjber, is never credited: not in a changelog bullet, THIRD_PARTY.md, release notes, README or store copy. Only other
  players are credited. `tools/check_package.py`
  fails a zip without that section or README's `## Credits`.

## Native composition

Load Forever Core's [Retail UI style skill](https://github.com/cjber/forever-core/blob/main/.agents/skills/wow-retail-ui-style/SKILL.md), [asset registry](https://github.com/cjber/forever-core/blob/main/docs/asset-registry.md) and
[native composition contract](https://github.com/cjber/forever-core/blob/main/docs/ui-composition.md) before UI or screenshot work. Review a complete lockup against the native host
and current SkillUp/Adventure Guide references before implementing a redesign. Record tab orientation
and owning edge, all four image-frame edges, icon source crop and single chrome owner. Freshness and
geometry checks do not validate these relationships. AI concepts are proposals, not client evidence.

## Extra rules from the layout audit round

- Never merge a change to `UI/` that leaves `python3 tools/visual_audit.py` red: read the rendered images, not just
  the diff.
- Do not edit `.luacheckrc` to hide a real warning. Add a `read_globals` entry only for a genuine WoW API global.
- Read the live roots in `.sloppatrol/instructions.md` before deleting code as unused.

## Release flow

Follow `.agents/skills/release/SKILL.md`. Keep changes under an appropriate `CHANGELOG.md` version heading, run the full gate, and check the packaged TOC contents before releasing. `X-Curse-Project-ID` and `X-Wago-ID` stay `0` (the packager's "no project") until the store projects exist; then set the real IDs and confirm the `CF_API_KEY` and `WAGO_API_TOKEN` secrets. The BigWigs packager reads `.pkgmeta`, substitutes the release version in the TOC, and publishes the changelog entry as release notes.
