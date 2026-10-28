# Changelog

All notable changes to Field Guide Forever are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning.

## [Unreleased]

- **Client constants re-pinned to build 1.60.1.70658.** The bundled zone, map and family tables are byte-identical to the 1.60.1.70630 pin, so nothing player-visible changes; the recorded build and every pinned constant move together.

## [0.3.8] - 2026-10-28

- **Adopt the suite's shared gitleaks config.** The CI secret-scan job now runs `.gitleaks.toml` with the same rules as the rest of the suite.

## [0.3.7] - 2026-10-27

- **Client constants regenerated for build 1.60.1.70630.** Zone, map and family constants come from the new build, and the pin readers now take the newest Forever build from wago.tools' `wowf` product as well as `wow_classic_beta`. wago lists 1.60.1.70630 only under `wowf`, so the daily refresh had been reporting itself already current and the bundled constants had stayed on the previous build.

## [0.3.6] - 2026-10-26

### Fixed

- **The cosmetic-rewards status column no longer collides with the locked marker.** `Locked · Mastered` is wider than
  the 86-unit status box it was given, so the right-justified text overflowed into the `—` marker beside it; the label,
  marker and status boxes now share the card's width with an 8-unit gutter each. The README mock's "Filter species"
  dropdown also draws an opaque surface under `common-dropdown-bg`, whose atlas centre is translucent and let the
  creature list show through the menu rows.

### Changed

- **Use Blizzard context menus for zone and filter choices.** The journal's custom rectangular panels are replaced by
  `MenuUtil` radio menus, and the filter preview now shows the client's dropdown artwork instead of a made-up modal.

## [0.3.5] - 2026-10-26

### Changed

- **The journal's paper tabs are replaced by the client's own `LargeSideTabButtonTemplate` plates**, hung off the
  right edge exactly as the Quest Log does them: 51x60 `questlog-tab-side` art, a 29x29 icon per tab, the
  `QuestLog-Tab-side-Glow-select` glow on the active one and the native hover glow, with the tab's name in the
  tooltip. The band the paper tabs used is gone, so the breadcrumb, search row and panes move up.
- **The addon icon is the client's `INV_Misc_Book_09`** instead of a bundled texture, so the Field Guide ships no
  raster art of its own.

## [0.3.4] - 2026-10-26

### Changed

- **The settings page is now drawn by Forever Core's shared `UI/SettingsPage.lua`**, vendored byte for byte. Every option, label, tooltip and saved value is unchanged: the same four checkboxes write the same `options` keys, the micro-menu toggle still refreshes the button, and the binding note still sits under the rows. The page's own heading is still "Field Guide Forever options".

## [0.3.3] - 2026-10-26

### Changed

- Field Guide tabs are now large square plates docked along the bottom edge of the window, replacing the paper tabs inside the frame; the freed band moves the breadcrumb, search and list up.

## [0.3.2] - 2026-10-25

### Added

- Add a configurable Field Guide button to the micro menu, with the Shift-F binding.

## [0.3.1] - 2026-10-23

### Changed

- Client constants now track the newest Forever build, 1.60.1.70532, so the daily data refresh and the pinned generator check agree again.

## [0.3.0] - 2026-10-22

### Added

- An additive minor-1 API with `Spawns` and `ZoneSpawns` for character-local creature progress and QuestieDB spawn coordinates.
- `tools/layout_options.py` and `docs/screenshots/options/`: design mockups of the four Field Guide window shapes under consideration - the shipping paper tabs, an external square-tab spine on each edge, a World Map sidecar drawer, and a LEGACY sub-panel - all rendered from the real catalogue and client art.

## [0.2.2] - 2026-10-22

### Changed

- Field Guide spacing, tabs, list rows, and detail cards now line up across the addon and its screenshots; thanks to @cillian for the idea.
- Creature icons now use each NPC's real client model where a verified matching icon exists, with name, family and type fallbacks shared by the addon and mockups.

## [0.2.1] - 2026-10-22

### Fixed

- Creature icons and displayed types now come from generated NPC metadata instead of QuestieDB's NPC-title field, so entries no longer show a placeholder glyph; unmapped NPCs use a neutral creature icon.
- The addon and the README mock art resolve creature icons through the same generated data and agree on the fallback.

## [0.2.0] - 2026-10-21

### Added

- Character-local first sightings from visible hostile nameplates/targets, first observed deaths, and uncapped recorded-death totals separate from ten-kill mastery.
- First rare and shiny records, plus tier gems, health-bar accents and a brief first-discovery highlight on known unit frames.
- An Instances journal populated by encounter-start and successful encounter-end events, with boss attempts, clear counts, personal firsts and difficulty labels.
- A default-on, opt-out `WFAStats` exchange for cumulative creature/instance counters and earliest firsts, plus a public shared leaderboard API.
- A QuestieDB runtime catalogue and generated client constants refreshed from pinned wago.tools DB2 exports.
- Schema 2 migration from the prior synthetic catalogue IDs by exact NPC name; `Core/LegacyIds.lua` is migration-only and will be removed in the next release.
- Updated the mock journal pages and zone previews for the QuestieDB backed interface.

### Changed

- Removed the hand-authored creature catalogue. Install Questie or QuestieDB to browse creatures.

## [0.1.1] - 2026-10-21

### Fixed

- The Open Journal and Track Species buttons overlapped and ran off the right edge of the window in every
  screenshot: the renderer now draws them from the bar's own anchors, exactly where the addon puts them.

### Added

- `tools/visual_audit.py`: the rendered scenes are checked against the layout manifest, so a control that leaves
  the frame, overlaps another control or sits closer than 8 units to one never reaches a screenshot or a release.

## [0.1.0] - 2026-10-21

### Added

- A cosmetic creature catalogue for ten Classic starting zones, with real families, level ranges and field notes.
- Specimen counts, four research ranks and zone completion.
- Rare variants with a three-sighting target and shiny variants with a 1-in-500 roll.
- A session sighting log, search, filters and CREATURES, RARES and SHINY tabs.
- Species tracking, a movable window that remembers its position, and `/fieldguide` and `/fg` toggles.
- A versioned public API for other addons.
