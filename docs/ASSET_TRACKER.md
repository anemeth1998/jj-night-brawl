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
| Idle sheet | `sprites/jj/idle/sheet-transparent.png` | yes | Yes | 🟢 |
| Walk sheet | `sprites/jj/walk/sheet-transparent.png` | yes | Yes | 🟢 |
| Attack sheet | `sprites/jj/attack/sheet-transparent.png` | yes | Yes | 🟢 |
| Hurt sheet | `sprites/jj/hurt/sheet-transparent.png` | yes | Yes | 🟢 |
| Kick / jump / special / smoke | `sprites/jj/{kick,jump,special,smoke}/` | — | Yes | 🟢 |
| Reference | `sprites/jj/reference.jpg` | — | No | 🟡 |

## Enemy tracker

| Asset | Path | Meta | In git | Status |
|-------|------|------|--------|--------|
| Idle sheet | `sprites/enemy/idle/sheet-transparent.png` | yes | Yes | 🟢 |
| Walk sheet | `sprites/enemy/walk/sheet-transparent.png` | yes | Yes | 🟢 |
| Attack sheet | `sprites/enemy/attack/sheet-transparent.png` | yes | Yes | 🟢 |
| Per-archetype unique sheets | `sprites/enemies/{biz,maga,gothm,gothf}/*-sheet.png` | — | Yes | 🟢 |

## FX tracker

| Asset | Path | Meta | In git | Status |
|-------|------|------|--------|--------|
| Impact / hit FX | `sprites/fx/sheet-transparent.png` | yes | Yes | 🟢 |
| Muzzle / spark / smoke particles | code-driven / TBD art | — | — | 🔴 |

## UI tracker

| Asset | Notes | Status |
|-------|-------|--------|
| HUD (HP, meter, wave) | Canvas HUD in `web/src/game/engine.ts` | 🟢 |
| Touch controls | Virtual pad in `GameCanvas.tsx` | 🟢 |
| Title / pause / game over | Title card + banners | 🟢 |
| Slogan speech bubble chrome | Engine speech bubbles | 🟢 |

## Sound tracker

| Asset | Notes | Status |
|-------|-------|--------|
| Punch / kick / hurt SFX | Procedural Web Audio in `web/src/game/audio.ts` | 🟢 |
| Riff sting | Procedural | 🟢 |
| Gun shot | Procedural | 🟢 |
| Wave clear / smoke ambience | Procedural | 🟡 |
| Music bed | Title/menu `tdm-8bit.mp3`; no brawl bed yet | 🟡 |
