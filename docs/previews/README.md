# Field Guide visual references

`field-guide-model-layout.png` is a composition preview. Its Siege Golem image is a Classic model-viewer reference, not a capture from the Forever client. The addon uses a native `PlayerModel`; its loading, camera framing and availability require an in-game check. Headless gallery images show the portrait fallback.

The location image is native QuestionFrame zone artwork, not map tiles. `UI/Art.lua` lists the selected file IDs. Illustrations depicting changed terrain are omitted. Garrison assets remain blacklisted; the candidate sheet includes one only as an explicitly labelled comparison.

To inspect the wider native asset set:

```sh
FOREVER_CORE=../forever-core uv run --with pillow==12.3.0 python tools/zone_art_audit.py
FOREVER_CORE=../forever-core uv run --with pillow==12.3.0 python tools/zone_art_audit.py --zones
```

These commands write the two contact sheets in this directory. Open both with `xdg-open`. The sheets are candidate inventories, not an allowlist or evidence that every pictured location matches Forever.
