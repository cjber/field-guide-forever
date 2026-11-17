---
name: release
description: "Prepare, publish and verify a complete Field Guide Forever release. Use for /release or cutting a release, including README and store copy, screenshots, CurseForge and client installation."
---

# Release Field Guide Forever

Run from the repository root. Read `AGENTS.md`, then the suite skills in `cjber/forever-core`
(`.agents/skills/wow-forever-addon` and `.agents/skills/wow-addon-publish`), the `copywriting`
skill for README, store, release-note and UI copy, and `wow-mock-screenshots` for images. Those
supply the shared standards and store procedures; this checklist supplies the completion criteria.
Use the user's existing authorization. A preparation-only request ends before tags or uploads.

## Prepare main

1. Fetch origin and tags. Inventory open PRs, local branches, worktrees and unpushed changes. Land
   only authorized, reviewed PRs with every check green on their current heads. List anything left out.
2. Inspect the latest `refresh-data.yml` run and open data PRs. `python3 tools/check_generated.py`
   reproduces the selected pins; it does not prove they are the newest build.
3. Prepare the release on a branch from fresh main. Choose the version from the changes since the
   last tag. Run `python3 tools/changelog.py release X.Y.Z`: it writes `## [X.Y.Z] - YYYY-MM-DD`
   (UTC date) from the `changes/*.md` fragments and deletes them.
   Keep the TOC version as `@project-version@`. Run `python3 tools/changelog.py --check X.Y.Z` and
   `python3 tools/changelog.py --check`, and read the extracted notes.

## Refresh every presentation surface

4. Compare `README.md` and `docs/curseforge.md` with the behaviour being released. Remove stale
   claims. Run the shared `wow-forever-addon/check_copy.py` on both files and `tools/check_family.py`.
5. Run `FOREVER_CORE=<forever-core checkout> python3 tools/mockups.py`, then
   `python3 tools/check_screenshots.py --record` and `python3 tools/visual_audit.py`. Open the store
   images at full size, step through `docs/screenshots/demo.gif`, and keep every store image under 2 MB.
6. Write the store plan: summary (the TOC `## Notes`), description, logo (`media/icon-400.png`) and
   the gallery files with captions in order, plus the exact stale images to delete.

## Verify and publish

7. Run the full gate from `AGENTS.md`. Agents test in game only through `INGAME` requests to the
   `wow in-game` agent (`wow-forever-addon/in-game.md#requesting-a-check`); record the user's own
   `/reload` checks and their results separately.
8. Ship the release PR signed and green. Merge only within the user's authorization, then wait for
   the full `ci.yml` push run on main at the exact commit to be tagged: `tools/release_check.py`
   accepts nothing else.
9. Get that commit smoked. Every release needs a green `headless-smoke` commit status on the exact commit it ships, and
   `tools/release_check.py` refuses without one. The `forever-smoke` timer posts it for every commit a release would
   ship; read it with `gh api repos/cjber/field-guide-forever/commits/<full sha>/statuses </dev/null`. When it is
   missing, send the `wow in-game` agent `INGAME field-guide-forever <full sha> from <your kiln id>` with `kind: smoke`
   (`wow-forever-addon/in-game.md#requesting-a-check`) and wait for its reply; never run the client yourself. `INGAME
   FAIL` is a release blocker: fix the errors it names. `INGAME BLOCKED` goes to the user as the release's blocker.
10. Confirm `FieldGuideForever.toc` carries the real `X-Curse-Project-ID` (`0` means
    the project does not exist yet and the packager skips the upload). Check `gh secret list` shows
    `CF_API_KEY`; never print their values. Tag `vX.Y.Z` signed at the verified
    commit and push it, or dispatch the Release workflow on main with `version`.
11. Watch the release run. Its log must show the CurseForge ID with `[token set]` and a `Success!` after
    each upload; a missing token skips that store while the run stays green. Download the GitHub zip
    and check the substituted version, `media/Icon.tga` and every TOC-loaded file.
12. Apply the store plan on CurseForge (the user uploads the CurseForge logo and deletes images).
    Verify each page after a reload, and report moderation as pending with its URL.
13. If installation was requested, run `wowaddon --flavor forever sync gh:cjber/field-guide-forever`,
    remove any dev symlink first, and tell the user to `/reload`.

## Addon checks

- User checks after `/reload`: `/fg` opens the journal, a kill on a targeted creature adds to its
  count, Shift-F opens it, and without QuestieDB the install prompt shows.

## Command discovery

`.agents/skills/release/SKILL.md` is the canonical file. Claude and Pi load it through the
`.claude/skills/release` and `.pi/skills/release` symlinks; Pi's `/release` prompt loads it too.
