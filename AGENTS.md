# AGENTS.md

Bestiary Forever is a World of Warcraft: Forever addon (Interface 16001) that keeps a cosmetic field journal of the
creatures a character has met. It records specimens, rare variants and shiny colour variants per zone. It never grants
player power, changes combat or calls a protected function.

## Commands

```sh
luacheck .
stylua --check .
for spec in tests/*_spec.lua; do lua5.1 "$spec" || exit 1; done
```

Run all three from the repository root before every change is handed over. The specs are plain Lua 5.1 scripts, not
busted: they load `tests/wow_mock.lua`, build a sandbox with `Mock.Harness()`, and assert with `assert(...)`. A spec
prints one `name: ok` line and exits non-zero on failure.

## Layout

- `BestiaryForever.toc` — the only file list the client reads. Locales load first, then Data, Core and UI; a new file
  that is not in the TOC never runs.
- `Locales/enUS.lua` — every phrase the UI shows, keyed by the English text. `L["..."]` is the only source of
  player-visible text in UI files.
- `Data/Creatures.lua` — the zone catalogue. Real Classic names, families and level ranges with stable integer ids and
  one sentence of in-voice lore per species.
- `Core/Model.lua` — pure state arithmetic: ranks, completion, variant rolls and the session sighting ring. It has no
  WoW API, no I/O and no globals beyond `ns.Model`. The random function is injectable so specs are deterministic.
- `Core/Core.lua` — saved variables, the character key, catalogue lookup, the combat-log kill path, progress
  callbacks and the slash commands. Event handlers are wrapped by `Core/SafeCall.lua`.
- `Core/API.lua` — the public addon-to-addon contract. It is versioned and answers nil until the saved state is known,
  so callers can ask again after login instead of reading an empty catalogue.
- `Core/Settings.lua` — the options panel registration.
- `UI/` — `Art.lua` owns the palette and frame helpers; `Window.lua` owns the shell and selection state; `List.lua` and
  `Detail.lua` draw the two panes; `Tooltip.lua` owns hover text.
- `tests/` — `wow_mock.lua` plus the model, data and API specs. Nothing in `tests/` ships.
- `docs/screenshots/` — screenshots referenced from the README; development only.

## Rules

- Lua 5.1 in the game's sandbox: no `require`, no package path and no new global except the saved variable
  `BestiaryForeverDB`, the public `BestiaryForever` table and the slash globals the client expects.
- Keep `Core/Model.lua` pure. If it needs `GetZoneText`, `UnitName`, a frame or a saved variable, the code belongs in
  `Core/Core.lua` or the UI. The specs must be able to call Model with a table and a random function only.
- The combat-log handler writes tables and schedules work. It never touches a frame: the UI refresh is deferred to the
  next frame by the progress callback. Prove any new kill-path change in `tests/api_spec.lua` or with a `/reload`
  check.
- Every kill is `UNIT_DIED` on a hostile NPC whose name matches the current zone's catalogue. Catalogue names are
  matched case-insensitively; ids are never reused or renumbered.
- Keep saved state flat and serialisable: `state.species[id] = { count = n, rare = n, shiny = n }`. Do not save frames,
  functions, userdata or the session sighting log.
- Use `L["whole sentence"]` for text, including format strings. No bare English in `UI/`.
- Use tabs, `---@type` annotations, namespaces through `local addonName, ns = ...`, and sentence-case comments that
  explain why. Do not add comments that restate the next line.
- Use the palette in `UI/Art.lua` and the client's own `GameFontNormal`, `GameFontHighlight` and
  `GameFontDisableSmall`; do not ship custom fonts or stretch icons.
- Do not edit `.luacheckrc` to hide a real warning. Add a `read_globals` entry only for a genuine WoW API global.

## Release flow

1. Move the entries under `## [Unreleased]` in `CHANGELOG.md` into a new `## [x.y.z] - YYYY-MM-DD` section.
2. Run the three commands above and review the diff.
3. Tag the commit `vX.Y.Z` (or start the Release workflow on `main` with the version). The tag supplies
   `@project-version@` in the TOC.
4. The BigWigs packager reads `.pkgmeta`, ships only the addon files, README and licence, and publishes the changelog
   entry as the release notes.

## Data changes

The catalogue is hand-curated, not generated. When adding a species, keep its id stable, give it a real Classic name,
one of the ten families and a lore line that describes the creature rather than inventing mechanics. Add a rare only
when the creature was actually rare in the original game.
