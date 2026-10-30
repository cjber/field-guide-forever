# Third party materials

## Inputs

| Input | What it gives | Pin | Licence | Ships in zip |
|---|---|---|---|---|
| WoW: Forever client tables, via [wago.tools](https://wago.tools) | Zone names, instance types, creature families and portrait IDs in `Data/Client.lua` | `--build` default in `tools/gen_zones.py` | Blizzard Entertainment's game data | Yes, as generated data |
| [CMaNGOS classic-db](https://github.com/cmangos/classic-db), the [wow-listfile](https://github.com/wowdev/wow-listfile) community listfile and the client's `CreatureModelData`, via wago.tools | Which species icon each creature shows, in `Data/CreatureIcons.lua` | `CMANGOS_COMMIT`, `LISTFILE_TAG` and `MODEL_DATA_URL` in `tools/gen_creature_icons.py` | classic-db: GPL-3.0; the listfile publishes no licence and only file IDs are used; client data: Blizzard Entertainment's | Yes, as generated data |
| [QuestieDB](https://github.com/Questie/QuestieDB) and Questie, installed by the player | Creature names, levels, ranks and spawn locations, read at runtime (`Integrations/QuestieDB.lua`) | None; whatever the player has installed | QuestieDB carries no licence; nothing is copied | No |
| QuestieDB-Forever release zip | The mock catalogue the specs run against | `TAG` in `tools/gen_mock_catalogue.py` | QuestieDB carries no licence | No, tests only |
| [forever-core](https://github.com/cjber/forever-core) | The vendored shared files listed in `PATHS` in `tools/check_core_shared.py`, and the renderer `tools/mockups.py` draws the README scenes with | forever-core `main`, checked by `.github/workflows/core-shared-drift.yml` | GPL-3.0-or-later | The vendored Lua files, yes; the renderer, no |
| Client art | Creature portraits, icons and window textures, drawn from the player's own client at runtime | The client the player runs | Blizzard Entertainment's | No |

## Ideas and contributors

Credit for the ideas and reports behind the addon.

| Who | What | Notes |
|---|---|---|
| cjber | Asked for the Field Guide's visual polish | |

Thanks also to everyone else who reported a bug or asked for a feature, here or on CurseForge.
