# About the app

Field Guide Forever is a World of Warcraft: Forever addon written in Lua 5.1. It cannot run outside the
game client, and this patrol never starts it (see the rules below). What runs here is its headless test harness: each
`tests/<name>_spec.lua` stubs the client API, loads the addon files the TOC lists, and checks one
feature. Run a spec with `luajit tests/<name>_spec.lua`; a failing spec exits non-zero and prints the
failed assertion. `luacheck <file>` lints a file.

`python3 tools/visual_audit.py` audits the layout of the addon's rendered scenes and
`python3 tools/check_screenshots.py` fails when an image is older than the sources it is drawn from.
Both are part of the gate. `tools/check_core_shared.py` is the core drift gate.

Use the specs and `luajit -e` one-liners that load the harness to check what a change claims. Report a
spec that fails, an error that a spec prints, or a behaviour a spec shows that the change does not
intend.

## Sign in

No sign-in.

## Important flows

- The journal of creatures met: what marks one as met, how the entry is stored, and what the window
  shows for a creature you have not met.
- Zones and filters in the journal.
- Saved variables: what survives a `/reload` and what does not.

## Never do these things

- Never start the game, Battle.net, Lutris or Wine. The headless client (forever-core's `wow-forever-addon/in-game.md`) tests the build linked into the game, not this checkout, so in-game checks belong to the agent that ships a change.
- Never edit, move or delete files.
- Never use the network.
