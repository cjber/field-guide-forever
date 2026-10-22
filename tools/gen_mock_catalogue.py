"""Extract a disposable screenshot fixture from a hash-pinned QuestieDB Forever release."""

from __future__ import annotations

import hashlib
import subprocess
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
TAG = "v1.0.6"
SHA256 = "d78b066c362eaf28258d9e2d041c0a7b03d6943a2dfc741dec70c6bfd8e1fc27"
URL = f"https://github.com/Questie/QuestieDB/releases/download/{TAG}/QuestieDB-Forever.zip"
ARCHIVE = CACHE / f"QuestieDB-Forever-{TAG}.zip"
EXTRACTED = CACHE / f"questiedb-{TAG}"
FIXTURE = CACHE / f"questiedb-mock-catalogue-{TAG}.tsv"


def main() -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    if not ARCHIVE.is_file():
        request = urllib.request.Request(URL, headers={"User-Agent": "FieldGuideForever-mockup"})
        ARCHIVE.write_bytes(urllib.request.urlopen(request, timeout=30).read())
    digest = hashlib.sha256(ARCHIVE.read_bytes()).hexdigest()
    if digest != SHA256:
        raise SystemExit(f"QuestieDB {TAG} checksum mismatch: {digest}")
    toc = EXTRACTED / "QuestieDB" / "QuestieDB_Forever.toc"
    if not toc.is_file():
        EXTRACTED.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(ARCHIVE) as archive:
            archive.extractall(EXTRACTED)
    subprocess.run(
        ["luajit", "tools/extract_mock_catalogue.lua", str(toc.parent), str(FIXTURE)],
        cwd=ROOT,
        check=True,
    )
    rows = sum(1 for _ in FIXTURE.open(encoding="utf-8"))
    print(f"Extracted {rows} mock NPC rows from QuestieDB {TAG} ({digest}) into ignored cache.")


if __name__ == "__main__":
    main()
