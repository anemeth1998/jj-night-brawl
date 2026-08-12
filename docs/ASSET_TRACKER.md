# Asset Tracker — JJ: Night Brawl

## Pipeline notes

| Item | Convention |
|------|------------|
| Runtime sheet | Prefer `sheet-transparent.png` (magenta keyed) |
| Meta | `pipeline-meta.json` beside each sheet — grid / cell size / frame labels |
| Background plates | `assets/Background/<stage>/{sky,far-bg,mid-bg}.png` — 1536×864 |
| Land into repo | See [HOW_TO_ADD_BINARIES.md](../HOW_TO_ADD_BINARIES.md) and [ASSET_MANIFEST.md](../ASSET_MANIFEST.md) |

Expected layout:

```
assets/
  Background/
    downtown/       sky, far-bg, mid-bg, preview
    opera-alley/
    geary-strip/
    train-yard/
    water-tower/
  map/              downtown trio alias for current iOS loader
  sprites/
    jj/             idle|walk|attack|hurt (+ reference)
    enemy/          idle|walk|attack
    fx/             impact sheet
```

## Map / Background tracker

| Asset | Path | In git | Status |
|-------|------|--------|--------|
| Downtown sky/far/mid | `assets/Background/downtown/` + `assets/map/` | Yes | 🟢 |
| Hoover Opera Alley | `assets/Background/opera-alley/` | Yes | 🟢 |
| Geary Blvd Strip | `assets/Background/geary-strip/` | Yes | 🟢 |
| Yard & Overpass | `assets/Background/train-yard/` | Yes | 🟢 |
| Water Tower Roof | `assets/Background/water-tower/` | Yes | 🟢 |

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
