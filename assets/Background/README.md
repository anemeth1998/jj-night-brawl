# Background — JJ Night Brawl

Parallax stage plates for **JJ: Night Brawl**. Drop these into Xcode as `map_sky` / `map_far` / `map_mid`, or load per-stage as `map_<id>_sky` etc.

All plates are **1536×864** PNG.

| Folder | Stage | Suggested wave |
|---|---|---|
| `downtown/` | Downtown Junction City | 1–2 |
| `opera-alley/` | Hoover Opera Alley — clock tower + pink marquee | 3 |
| `geary-strip/` | Geary Blvd Strip — gas canopy + diner | 4 |
| `train-yard/` | Yard & Overpass — I-70 + freight | 5 |
| `water-tower/` | Water Tower Roof — boss arena | Boss |

Each stage folder:

- `sky.png` — no-scroll atmosphere
- `far-bg.png` — slow skyline (`camX * 0.12`)
- `mid-bg.png` — street / arena (`camX * 0.4`)
- `preview.png` — stacked QA composite
- `*.prompt.txt` — generation prompts (new stages)

Style: 16-bit night, navy/violet sky, hot pink + cyan neon, empty lower third for the walk belt. No fighters.

The original downtown trio is also copied to `assets/map/` for the current iOS loader (`map_sky` / `map_far` / `map_mid`).
