-- tools/changelog.py --check accepts the maintenance entry forever-core writes when it re-releases every addon: a
-- dated patch with the sync marker and a plain bullet, no bold lead, kept below ## [Unreleased] and above the last
-- normal release entry. This addon has no in-game "What's new" line, so the entry is release notes only.
local script = [==[
import pathlib
import sys
import tempfile

sys.path.insert(0, "tools")
import changelog

text = """# Changelog

## [Unreleased]

## [0.7.4] - 2026-11-12

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [0.7.3] - 2026-11-11

- **Tells you which addon to update.** The shared warning names the addon to update.
"""

with tempfile.TemporaryDirectory() as folder:
    root = pathlib.Path(folder)
    (root / "CHANGELOG.md").write_text(text, encoding="utf-8")
    changelog.ROOT = root
    changelog.main(["--check", "0.7.4"])

assert changelog.section(text, "0.7.4").startswith("<!-- forever-core-sync -->")
]==]
local path = os.tmpname()
local file = assert(io.open(path, "w"))
file:write(script)
file:close()
local ok = os.execute("python3 " .. path)
os.remove(path)
assert(ok == 0 or ok == true, "tools/changelog.py --check accepts a maintenance entry on top of a normal one")
print("changelog_spec: ok")
