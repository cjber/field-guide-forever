# Third party materials

## Inputs

| Input | What it gives | Pin | Licence | Ships in zip |
|---|---|---|---|---|
| WoW: Forever client tables, via [wago.tools](https://wago.tools) | Zone names, instance types, creature families and portrait IDs in `Data/Client.lua` | `BUILD` in `tools/gen_zones.py` | Blizzard Entertainment's game data | Yes, as generated data |
| [CMaNGOS classic-db](https://github.com/cmangos/classic-db), the [wow-listfile](https://github.com/wowdev/wow-listfile) community listfile and the client's `CreatureModelData`, via wago.tools | Which species icon and portrait display ID each creature shows, in `Data/CreatureIcons.lua` | `CMANGOS_COMMIT`, `LISTFILE_TAG` and `MODEL_DATA_URL` in `tools/gen_creature_icons.py` | classic-db: GPL-3.0; the listfile publishes no licence and only file IDs are used; client data: Blizzard Entertainment's | Yes, as generated data |
| [QuestieDB](https://github.com/Questie/QuestieDB) and Questie, installed by the player | Creature names, levels, ranks and spawn locations, read at runtime (`Integrations/QuestieDB.lua`) | None; whatever the player has installed | QuestieDB carries no licence; nothing is copied | No |
| QuestieDB-Forever release zip | The mock catalogue the specs run against | `TAG` in `tools/gen_mock_catalogue.py` | QuestieDB carries no licence | No, tests only |
| [forever-core](https://github.com/cjber/forever-core) | The vendored shared files listed in `PATHS` in `tools/check_core_shared.py`, and the renderer `tools/mockups.py` draws the README scenes with | forever-core `main`, checked by `.github/workflows/core-shared-drift.yml` | GPL-3.0-or-later | The vendored Lua files, yes; the renderer, no |
| Client art | Creature portraits, icons and window textures, drawn from the player's own client at runtime | The client the player runs | Blizzard Entertainment's | No |
| Addon icon, made for this addon | `media/icon.svg`, rendered to `media/icon-400.png` and `media/Icon.tga` by forever-core's `wow-forever-addon/render_icon.py` | `media/icon.svg` | GPL-3.0-or-later | `Icon.tga` yes; the SVG and 400 px PNG no |
| Rarity frame ornaments, original art made for this addon with AI assistance, no Blizzard art | The silver, gold and shiny laurel target-frame ornaments, in `media/Rarity/*.tga` | Drawn for this addon | GPL-3.0-or-later | Yes |
| Ko-fi's Support me on Ko-fi button | The support button in the README (`ko-fi.com/img/githubbutton_sm.svg`) and its PNG render, `docs/kofi-button.png`, in the store description | None: the README links Ko-fi's live file; the PNG is rendered from it | Ko-fi's brand asset, used as Ko-fi provides it for linking to a Ko-fi page | No |
| `docs/github-sponsors-button.png` | The GitHub Sponsors button in the README and store description; drawn here to match the Ko-fi button, with the heart from GitHub's [Octicons](https://github.com/primer/octicons) and the Adwaita Sans font | None | Octicons: MIT; Adwaita Sans: SIL OFL 1.1 | No |
| `docs/discord-button.png` | The Discord button on the store page; drawn in forever-core with Discord's logo from [Simple Icons](https://simpleicons.org) and the Adwaita Sans font | None | Simple Icons: CC0; Adwaita Sans: SIL OFL 1.1; the logo is Discord's, used to link to a Discord server | No |

## Ideas and contributors

Credit for the ideas and reports behind the addon.

| Who | What | Notes |
|---|---|---|

Thanks also to everyone else who reported a bug or asked for a feature, here or on CurseForge.
