# About the app

Field Guide Forever is a World of Warcraft: Forever addon in Lua 5.1. The game cannot run here. The benchmarks run
the headless harness the specs use, which stubs the client API and loads the files the TOC lists in
order.

- CI does not run Speedpatrol: this repo has no bench script, and the profile only times gate steps, which are
  too noisy on a shared runner to fail a pull request on.
- Keep a change only when it speeds up a file the TOC loads or the gate itself. A change to a spec, a
  bench or other measuring code is not a speed-up.
- Every change must pass the full gate in `AGENTS.md` under "Commands", with lua-language-server
  3.19.1 and stylua 2.5.2 first on `PATH`, the versions CI uses.
- Generated data, translations and the vendored `tools/forever_tools/` are never edited by hand.
- Commit only the files the change needs: no profiler output or scratch files.
- Never launch the game, Battle.net, Lutris or Wine, and never use the network.
