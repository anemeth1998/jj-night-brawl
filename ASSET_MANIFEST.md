# Asset manifest

## Background stages (in git)

All night parallax plates live in **`assets/Background/`**.

| Folder | Stage | Wave |
|---|---|---|
| `assets/Background/downtown/` | Downtown Junction City | 1–2 |
| `assets/Background/opera-alley/` | Hoover Opera Alley | 3 |
| `assets/Background/geary-strip/` | Geary Blvd Strip | 4 |
| `assets/Background/train-yard/` | Yard & Overpass | 5 |
| `assets/Background/water-tower/` | Water Tower Roof | Boss |

Each stage: `sky.png`, `far-bg.png`, `mid-bg.png`, `preview.png` (1536×864).

Downtown trio is also at `assets/map/` for the current iOS loader (`map_sky` / `map_far` / `map_mid`).

See [`assets/Background/README.md`](assets/Background/README.md).

## Menu / character-select loops (2026-08-12)

Full 16:9 alley loops. Same locked camera as Menu Select (brick wall, character on the right).

| Path | Frames | Motion |
|---|---|---|
| `assets/ui/menu-select-loop.mp4` | video (+ 50 PNG frames in project) | JJ smokes / idle |
| `assets/ui/andrew-hover.mp4` | 50 JPG `assets/ui/andrew-frames/f001–f050.jpg` | Types on laptop, drinks a soda, back to typing |
| `assets/ui/han-hover.mp4` | 50 JPG `assets/ui/han-frames/f001–f050.jpg` | Types on phone, pets a cat that walks by |

Character Select keeps all three loops playing in the background. Selecting JJ, Andrew, or Han reveals that fighter's loop and leaves it running (same as JJ's alley loop) until you pick someone else.



Text index is in git under [`assets/art-drops/`](assets/art-drops/). **JPG binaries** ship in:

`art-drops-characters-cutscenes-2026-08-12.tar.gz` (Grok project `05-backups/`)

Unpack to `assets/art-drops/` then commit (see that folder’s README).

| Path | Count | Who |
|---|---|---|
| `characters/jj/` | 22 | JJ (pink/black hair punk) |
| `characters/andrew/` | 13 | Andrew (striped hoodie) |
| `characters/han/` | 14 | Han (cat beanie) |
| `characters/group/` | 2 | Trio shots |
| `cutscenes/` | 5 | Story stills |

Matched pose sheet (Andrew + Han): front-idle, kneel, crouch, sit-cross-legged, walk, run, jump-fists, punch, over-shoulder, back, look-up, peace-stand, closeup-peace. JJ has extra action / personality poses.

## Sprites (fighter sheets)

Binary PNGs/GIFs for in-engine fighters may still live in `jj-night-brawl-assets-backup.tar.gz` until restored.

### JJ sprites
- sprites/jj/idle|walk|attack|hurt/sheet-transparent.png (+ frames, meta)
- sprites/jj/reference.jpg

### Enemies
- sprites/enemy/idle|walk|attack/sheet-transparent.png

### FX
- sprites/fx/sheet-transparent.png
