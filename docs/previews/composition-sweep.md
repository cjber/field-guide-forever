# Native composition sweep

Source audit of the eight active addons, using current `origin/main` rather than stale local main checkouts. Field Guide is checked at `e013ac2`. References identify host relationships, not blanket approval
of every pixel in a screenshot. Field Guide runtime changes await review of the single lockup proposal.

| Addon | Native pattern | Evidence |
| --- | --- | --- |
| Adventure Guide | QuestMapFrame outer side rail; one conditional icon border | `UI/Panel.lua`, `UI/ZoneIcon.lua` |
| Shortest Path | Native map host, no custom page tabs; shared portrait/inset report | `UI/Route.lua`, `UI/Report.lua` |
| SkillUp | Professions host, outer side tabs, inset detail and one icon frame | `UI/Gear.lua`, `UI/Route.lua`, `UI/List.lua` |
| Tweaks | Edit Mode sheet owns its bottom tabs and native NineSlice | `UI/Frames.lua` |
| Legacy | Native world map/tracker integration; shared portrait/inset report | `UI/Report.lua` |
| Commissions | Professions host, outer side tab, inset content and raw row icons | `UI/Window.lua` |
| Hoard | Portrait shell owns its bottom tab edge; raw item icons | `UI/Window.lua`, `UI/Results.lua` |
| Field Guide | Needs top-facing detail tabs, framed zone art and single icon framing | `UI/Detail.lua`, `UI/Art.lua`, `tools/mockups.py` |

## Field Guide corrections to implement after lockup review

- Replace the mid-content bottom-tab row with a native top-oriented tab system attached to the
  detail pane's upper boundary. Merely moving PanelTabButtonTemplate is insufficient.
- Put location art inside a native inset/map frame, clipped behind its four edges.
- Inspect source icons at native resolution and remove duplicate framing in runtime and renderer.
- Replace custom one-pixel WHITE8X8 card edges with the native host's frame treatment.
- Use semantic font colours and the host's own content surfaces. Keep zone art as content.

Core's `docs/ui-composition.md` owns the shared contract. The proposed mock is a direction for owner
review, not evidence that an atlas, mask or runtime path is valid.
