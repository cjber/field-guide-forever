# Changelog

All notable changes to Field Guide Forever are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning.

## [Unreleased]

Nothing yet.

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
