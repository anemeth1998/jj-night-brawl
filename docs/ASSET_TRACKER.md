# Asset Tracker — JJ: Night Brawl

## Pipeline notes

| Item | Convention |
|------|------------|
| Runtime sheet | Prefer `sheet-transparent.png` (magenta keyed) |
| Meta | `pipeline-meta.json` beside each sheet — grid / cell size / frame labels |
| Binary backup | External tar: `jj-night-brawl-assets-backup.tar.gz` (not in git via text connector) |
| Land into repo | See [HOW_TO_ADD_BINARIES.md](../HOW_TO_ADD_BINARIES.md) and [ASSET_MANIFEST.md](../ASSET_MANIFEST.md) |
| Raw sheets | Optional source art; runtime uses transparent sheets |

Expected layout after restore:

```
assets/
  map/          sky.png, far-bg.png, mid-bg.png
  sprites/
    jj/         idle|walk|attack|hurt (+ reference)
    enemy/      idle|walk|attack
    fx/         impact sheet
```

Meta example fields: `mode`, `rows`, `cols`, `cell_size`, `frame_labels`, `source`.

## Map tracker

| Asset | Path | In git | Notes | Status |
|-------|------|--------|-------|--------|
| Sky | `assets/map/sky.png` | No | External tar | 🟡 recovered ext. |
| Far BG | `assets/map/far-bg.png` | No | External tar | 🟡 recovered ext. |
| Mid BG | `assets/map/mid-bg.png` | No | External tar | 🟡 recovered ext. |

## JJ tracker

| Asset | Path | Meta | In git | Status |
|-------|------|------|--------|--------|
| Idle sheet | `sprites/jj/idle/sheet-transparent.png` | yes | No | 🟡 |
| Walk sheet | `sprites/jj/walk/sheet-transparent.png` | yes | No | 🟡 |
| Attack sheet | `sprites/jj/attack/sheet-transparent.png` | yes | No | 🟡 |
| Hurt sheet | `sprites/jj/hurt/sheet-transparent.png` | yes | No | 🟡 |
| Reference | `sprites/jj/reference.jpg` | — | No | 🟡 |
| Jump / smoke / victory | TBD | — | — | 🔴 |

## Enemy tracker

| Asset | Path | Meta | In git | Status |
|-------|------|------|--------|--------|
| Idle sheet | `sprites/enemy/idle/sheet-transparent.png` | yes | No | 🟡 |
| Walk sheet | `sprites/enemy/walk/sheet-transparent.png` | yes | No | 🟡 |
| Attack sheet | `sprites/enemy/attack/sheet-transparent.png` | yes | No | 🟡 |
| Per-archetype unique sheets | TBD | — | — | 🔴 |

## FX tracker

| Asset | Path | Meta | In git | Status |
|-------|------|------|--------|--------|
| Impact / hit FX | `sprites/fx/sheet-transparent.png` | yes | No | 🟡 |
| Muzzle / spark / smoke particles | code-driven / TBD art | — | — | 🔴 |

## UI tracker

| Asset | Notes | Status |
|-------|-------|--------|
| HUD (HP, meter, wave) | Not started | 🔴 |
| Touch controls | Not started | 🔴 |
| Title / pause / game over | Not started | 🔴 |
| Slogan speech bubble chrome | Not started | 🔴 |

## Sound tracker

| Asset | Notes | Status |
|-------|-------|--------|
| Punch / kick / hurt SFX | Not started — plan after core combat | 🔴 |
| Riff sting | Not started | 🔴 |
| Gun shot | Not started | 🔴 |
| Wave clear / smoke ambience | Not started | 🔴 |
| Music bed | Not started | 🔴 |

## Briefing template

Copy for new art / SFX requests:

```markdown
### Brief: <asset name>

- **Owner:**
- **Type:** sprite sheet | map layer | FX | UI | SFX | music
- **Path target:** `assets/...`
- **Dimensions / grid:** e.g. 2×2 @ 128, or single PNG
- **Magenta key:** yes / no
- **pipeline-meta.json:** required fields / frame labels
- **References:** link or `sprites/jj/reference.jpg`
- **Gameplay use:** idle | walk | attack | hurt | UI slot | etc.
- **Priority:** P0 / P1 / P2
- **Acceptance:** transparent sheet + meta + looks correct in-engine
- **Status:** 🔴 / 🟡 / 🟢
```
