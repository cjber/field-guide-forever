# Changelog

All notable changes to Field Guide Forever are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning.

## [Unreleased]

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
