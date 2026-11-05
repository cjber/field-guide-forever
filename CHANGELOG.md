# Changelog

All notable changes to Field Guide Forever are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning.

## [Unreleased]

- **Rarity marks no longer recolour health bars or names.** Field Guide leaves every target and nameplate health bar and name in the game's own reaction colours, and marks rarity with the glow and the RARE or SHINY tag only. A nameplate reused after a hostile rare now keeps its new unit's green, yellow or red reaction colour, and `/fg preview` off returns every plate to the game's own colour. Thanks to cjber for the report (#134).

## [0.3.33] - 2026-11-05

- The discovery toasts now play the achievement chime instead of loot fanfares. Thanks to cjber for the report (#130).

## [0.3.32] - 2026-11-05

- **Rare creatures and shinies stand out on the target frame and nameplates.** A silver, gold or shiny creature gives the target frame a soft tier-coloured aura, a tier-coloured health bar and name, and a RARE or SHINY tag above the name; its nameplate takes the tier colour, a soft glow and a small mark. Shiny creatures pulse gently. Copper creatures look exactly as before. `/fg preview` cycles all three tiers through every creature for the session without recording anything rare. Thanks to cjber for the idea (#123, #124).

## [0.3.31] - 2026-11-05

- **The creature list shows each creature's real face.** A row now draws the creature's client portrait from its display ID, so a deer, squirrel, toad or treant no longer borrows a shared paw or humanoid head. When the catalogue has no display ID, a much larger keyword and family map over the client's modern icons shows the right animal instead. Only the rows on screen are kept, so scrolling stays cheap.
- **The detail header and cards have room to breathe.** The subtitle no longer crowds the portrait cards, and a two-line card status such as "Only rare creatures have one" keeps a clear gap from the card's bottom edge.
- **The micro-menu button's tooltip keeps a minimum width.** Its short two-word title no longer squeezes the binding and description under it into a narrow column, and the creature and micro-menu tooltips now take that width from the same place.
- **Suite tooling stays in step with Forever Core.** The vendored shared-file check knows about the new tracker header menu spec. Nothing a player sees changes.

## [0.3.30] - 2026-11-05

- **The Field Guide micro-menu button stays inside the micro menu.** Blizzard's buttons slid aside past the menu's own edge, so the row ran over the action bar beside it. The menu now grows by the addon buttons, and the action bar and bags beside it move aside, as they do for Blizzard's own buttons.
- **Pressing the micro-menu button no longer logs an error.** Every press logged "attempt to concatenate field 'textureName'" in Blizzard's micro menu code.
- **A creature tooltip keeps a minimum width.** A short name such as "Rat" no longer squeezes the tooltip so the zone and variant lines under it wrap.

## [0.3.29] - 2026-11-05

- **The Forever addons settings page ends with a Ko-fi link.** If the addons help you, its Copy link button shows the address, ready to paste into your browser. Nothing is locked behind it, and it shows nowhere else.

## [0.3.28] - 2026-11-05

- **The zone picker scrolls.** Choose a zone lists 20 zones at a time and scrolls the rest, so every zone stays reachable on any screen.

- **Suite tooling stays in step with Forever Core.** The vendored menu-scroll check and the workflow that runs it pick up Forever Core's newest rules, and the unused dropdown helper is gone from the shared settings page. Nothing a player sees changes beyond the zone picker scrolling.

## [0.3.27] - 2026-11-05

- **Each creature's entry shows its three forms as collectible cards.** Common, Rare and Shiny sit side by side like the Appearances tab: a collected form shows the creature in a white, blue or gold quality border, a missing one is a dark silhouette with what it takes to collect it. A creature that never comes as a rare shows a muted "No rare form" card that never counts as missing. Every list row marks the three forms, the header counts rares and shinies in this zone and across all zones, and the filter gains "Missing shiny" and "Missing rare". The Overview, Variants and Records tabs are gone: records sit under the cards.

## [0.3.26] - 2026-11-05

- **The journal opens like the game's own windows.** It sits on the left beside your other panels, the way the Adventure Guide does, closes with Escape or when another left-hand window opens, and no longer floats over everything. It can still be opened in combat. The old dragged position is no longer saved.
- **The journal looks more like the game's own windows.** Every progress bar is the gold Professions bar, so zone completion no longer shows a lone green bar. Creature rows drop the gold underline, the zone path sits beside the portrait, and the "Creature portrait" caption and all-caps labels are gone: rewards read "Unlocked" or "Unlocks at Studied".
- **The Field Guide micro-menu button gets its own slot.** With Adventure Guide Forever also installed, both buttons asked for the place before Game Menu and Field Guide's sat on top of Adventure Guide's. Each now gets its own place, and the game's buttons move aside instead of being covered.
- **Field Guide has its own icon in the addon list.** The client's book icon gives way to the Forever family's gold frame around an open journal with a paw print, the same art as the store logo.
- **A new creature now shows on screen when you kill it.** The first kill of a species is announced at the top of the screen in the line the game uses for a newly explored area, with a page-turn sound; the creature is tagged New in the journal and the Field Guide micro button pulses until you open it. The big moments, a rare's first kill, a shiny, a mastered species and a zone with every creature recorded, get the game's own achievement toast; left-click one to open the journal on that creature. A big pull shows at most three toasts. Two new options turn the line and the toasts off. Thanks to cjber for the idea.
- **The settings page opens without an error.** Its title asked the game for a font Forever does not have, which logged a Lua error each time the page was built; it now uses the font the game's own settings pages title with.
- **No more Bindings.xml warnings at login.** The addon list no longer loads the key bindings file a second time as a UI file, so the five `Unrecognized XML` warnings on every login are gone. The bindings still work.

## [0.3.25] - 2026-11-05

- **No more "C stack overflow" errors from the micro-menu button.** It hooked the game's micro-menu update again on every refresh, so errors piled up and the frame rate dropped. It now hooks once.

## [0.3.24] - 2026-11-04

- **Client constants now name the 1.60.1.70790 build.** Zones, maps and creature families are regenerated from the new Forever client build, and the README scenes are re-rendered from it. The regenerated values match the previous build, so nothing a player sees changes.

## [0.3.23] - 2026-11-04

- **Kills are recorded again on Forever 1.60.1.** The client no longer lets addons read the combat log, so Field Guide now counts a kill when your target or a creature with a showing nameplate dies and nobody outside your group tagged it, and when a rare's map marker you saw alive turns dead nearby. Each death counts once, however many of these report it. A creature that dies with no nameplate and not targeted is not seen, so enemy nameplates (`V`) catch the most. Thanks to cjber for the report (#91).

## [0.3.22] - 2026-11-04

- **Suite tooling stays in step with Forever Core.** The vendored shared-file drift check and the dead-code scan pick up Forever Core's newest rules, so this addon's gate now rejects what the rest of the suite rejects. Nothing a player sees changes.


## [0.3.21] - 2026-11-04

- **Bundled client data follows Forever 1.60.1.70755.** Zone, map, family and creature display constants are regenerated from the new build, and every README scene is re-rendered against it.

## [0.3.20] - 2026-11-04

- **The shared asset scanner reads XML too.** Adopted from Forever Core: backdrop file attributes, inline script handlers and texture markup in XML text are checked against the same asset blacklist as Lua.

## [0.3.19] - 2026-11-04

- **Screenshot art stays on the reviewed UI build.** Client data refreshes no longer move journal, rarity or micro-menu artwork to an unreviewed build.

## [0.3.18] - 2026-11-03

- **Creature entries use one native journal layout.** Detail tabs join the top of their panel, zone illustrations have complete native frames, and creature icons keep one border. Related facts sit closer together without changing your saved progress, thanks to cjber for the report.
- **Rarity colours respect later frame updates.** Target and nameplate cleanup leaves colours changed by Blizzard or another addon untouched. Reused nameplates restore their current appearance instead of an earlier creature's colours, and the background tint now uses Forever's native texture field. Thanks to cjber for the report (#71).


## [0.3.17] - 2026-11-03

- **Leaderboards count observed kills consistently.** Estimated historical kills stay outside both personal and shared totals, and their baseline survives reloads. Opting out keeps personal boards available. Shared reports use the suite's bounded guild and group transport, with independent readers for other addons and complete kill totals alongside recent creature records.

- **Progress updates keep your place in the creature list.** Scrolling no longer jumps to the top after tracking a creature or recording progress.

- **Creature entries put the creature first.** A native model view sits beside matching zone artwork, with one research strip and Overview, Variants and Records tabs. The list leaves more room for the entry, and the window title reads Field Guide.

## [0.3.16] - 2026-11-03

- **The journal uses native textured content panels and tighter creature rows.** The list and detail share a marble inset, rows use the native highlight, and the smaller window keeps related information together. Screenshot rendering now preserves the template backgrounds and uses the same side tabs as the addon.

## [0.3.15] - 2026-11-03

- **Going back to an older version no longer erases your journal.** A save written by a newer Field Guide was replaced with an empty one at logout, losing every character's creatures, kills and options. The older version now leaves that save as it is, so updating again finds everything.
- **Shared stats from other players cost less to take in.** Every stats message from a group or guild member re-checked the whole shared table; a table already checked is no longer walked again, so a busy guild channel no longer slows the addon down as it fills.
- **Progress bars no longer flash full at zero.** A zero-width texture is treated as unset by the client, so empty mastery and zone progress bars could render as full width. Bars now hide their fill at zero and use native inset frame chrome for journal cards.
- **The loading screen disables journal controls.** Tabs, search, filters and the footer could remain active while QuestieDB was still loading, even though the catalogue views were hidden.
- **Creature rows and tooltips show rare variants you have found.** Both read one creature's record where the whole character's progress was needed, so a found rare variant never showed as known, a finished creature never got its tick, and the tooltip always said Locked.
- **The window shows its book portrait.** The icon was set on a texture name the window template does not have.
- **The filter button no longer calls a text-box-only method** while the window builds.
- **The daily data refresh moves the one build pin.** `BUILD` in `tools/gen_zones.py` is the only client build pin, so a refresh PR for a new client build passes its own regeneration check.

## [0.3.14] - 2026-11-03

- **The client constants and every generator pin follow build 1.60.1.70753.** The bundled zone, map, family and portrait tables are unchanged in what they contain; the recorded build, the source checksums and the pinned build in `tools/gen_zones.py`, `tools/check_generated.py` and `tools/micro_menu_render.py` move together, so the regeneration gate stays exact.

## [0.3.13] - 2026-11-02

- **The tracked species stays tracked after a reload.** Loading the saved variables dropped it, so every `/reload` or login cleared the Track Species choice.
- **The entry page shows its badges.** Rare variant known, Shiny seen and Tracked never appeared, and the variant cards stayed unknown, because the page was read from the wrong saved table.
- **A boss kill is logged in its instance.** The sighting log gave the boss's own name as the place.
- **Kill counts carried over from an older save say "at least".** A save from before kills were counted now marks them as an estimate.

## [0.3.12] - 2026-10-30

- **The addon ships its credits.** A new THIRD_PARTY.md lists every input with its pin and licence, and an Ideas and contributors table that credits each player whose report or idea is built, as the other Forever addons do. The README's Credits section is now a short paragraph that links it, and the package check fails a zip without either.

## [0.3.11] - 2026-10-30

- **Client constants re-pinned to build 1.60.1.70707.** The bundled zone, map and family tables are byte-identical to the 1.60.1.70685 pin, so nothing player-visible changes; the recorded build and every pinned constant move together.

## [0.3.10] - 2026-10-28

- **Client constants re-pinned to build 1.60.1.70685.** The bundled zone, map and family tables are byte-identical to the 1.60.1.70658 pin, so nothing player-visible changes; the recorded build and every pinned constant move together.

## [0.3.9] - 2026-10-28

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
