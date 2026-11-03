# Native journal composition

The gallery is rendered from client assets, not captured in game. The approved
AI concept establishes the direction only. Creature models still need a client
check; gallery scenes show the native portrait fallback.

## Sources

- Runtime: `UI/Window.lua`, `UI/Detail.lua`, `UI/List.lua` and `UI/Art.lua`.
- Renderer: `tools/mockups.py`, using Forever Core `113d426fe0d8ab18f068e7046e8bb6b46c57845c`.
- FrameXML discovery: Gethe/wow-ui-source `70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e`, client `1.60.1.69913`.
- Art cache: `1.60.1.70124`, Pillow `12.3.0`. Generated catalogue constants use the separate `1.60.1.70753` pin.

## Attachment and chrome ownership

| Element | Native source | Attachment and crop | Chrome owner |
| --- | --- | --- | --- |
| Window | `PortraitFrameTemplate` | Existing outer host and native portrait mask | Host template |
| Section tabs | `LargeSideTabButtonTemplate` | Right rail, `SetFillToInterior(true)`, native interior crop `0.03125..0.96875` | Side-tab template |
| Detail tabs | `PanelTopTabButtonTemplate` | `BOTTOMLEFT` to content `TOPLEFT`, width 104, spacing 112 | Tab template |
| Detail content | `InsetFrameTemplate` | 582 by 486, 28 below the detail host | Native NineSlice |
| Zone illustration | `Art.LOCATION_ART` numeric file IDs | Source `(33,0,223,128)`, scaled uniformly to 178.125 by 120 inside a 190 by 128 frame | Native inset frame, all four edges |
| Creature-list icons | `Art.SpeciesIcon` client textures | Full source texcoords, no extra overlay | Source icon's baked edge |

`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:290` initializes top tabs
with `SetTexCoord(0,1,1,0.25)`, scales their art to 75 percent height and anchors
the art to the button's bottom. The renderer crops source V coordinates
0.25 through 1 and flips vertically to match. Selected and inactive labels use
the native state offsets.

Artwork is inset from the zone frame's edges. Runtime content controls belong
to the detail inset, and its native NineSlice owns the border. The renderer
draws the panel before its content. Missing artwork hides the complete zone
frame and expands the creature viewport; the fallback caption and map action
have separate rows.

## Client check

After `/reload`, open `/fieldguide`, change sections and detail tabs, select
creatures in zones with and without illustrations, and confirm model loading,
fallback captions, complete borders and preserved list scrolling.
