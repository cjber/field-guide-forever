"""Check this addon's vendored files against cjber/forever-core main."""

import hashlib
import urllib.error
import urllib.request
from pathlib import Path

# The files this addon vendors from Forever Core. Field Guide is a private repo, so core's
# tools/check_consumers.py cannot read it over unauthenticated raw; this is the Field Guide side of that gate.
PATHS = (
    "Core/MicroButton.lua",
    "tests/micro_button_spec.lua",
    "UI/SettingsPage.lua",
    "tests/settings_page_spec.lua",
)


def main():
    failures = []
    for path in PATHS:
        url = f"https://raw.githubusercontent.com/cjber/forever-core/main/{path}"
        try:
            with urllib.request.urlopen(url, timeout=60) as response:
                expected = response.read()
        except (OSError, urllib.error.URLError, TimeoutError) as error:
            failures.append(f"{path}: could not read core main: {error}")
            continue
        actual = (Path.cwd() / path).read_bytes()
        if actual != expected:
            failures.append(
                f"{path}: consumer {hashlib.sha256(actual).hexdigest()[:12]} "
                f"core {hashlib.sha256(expected).hexdigest()[:12]}"
            )
    if failures:
        raise SystemExit("Vendored files differ from forever-core main:\n  " + "\n  ".join(failures))
    print(f"{len(PATHS)} vendored files match forever-core main.")


if __name__ == "__main__":
    main()
