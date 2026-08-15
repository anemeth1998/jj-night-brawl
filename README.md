# JJ: Night Brawl

Private repo for **JJ: Night Brawl** — a 32-bit side-scrolling beat-em-up.

## Play (web)

```bash
cd web
npm install
npm run dev
```

Then open http://localhost:5173. Title card → menu → Story / Endless. See [`web/README.md`](web/README.md).

## Repo contents

- `web/` — Vite + React canvas build (`src/game/` is the live engine)
- `assets/map/` — parallax backgrounds (sky, far, mid)
- `assets/Background/` — five night stages
- `assets/sprites/jj/` — protagonist sheets (idle, walk, attack, kick, hurt, jump, special, smoke)
- `assets/sprites/enemies/` — biz / MAGA / goth sheets
- `assets/sprites/andrew/` + `assets/sprites/han/` — roster idle/walk
- `assets/sprites/fx/` — impact FX
- `assets/audio/tdm-8bit.mp3` — title / menu 8-bit theme (loops title → menu)
- `ios/` — partial Swift stubs (full engine not restored)

Game-ready sheets are named `sheet-transparent.png` (magenta keyed) or `*-sheet.png` for per-archetype enemies.
`pipeline-meta.json` files record sheet grid / frame info.

## Game design (summary)

- **Genre:** side-scrolling beat-em-up (Streets of Rage style)
- **Protagonist:** JJ (punk aesthetic)
- **Enemies:** white-collar businessmen, MAGA conservatives, goth men/women
- **Moves:** punch, kick, jump, guitar-riff special (AOE), gun unlock after wave 3
- **Flavor:** punk slogan speech bubbles on special; cigarette smoke break between waves
- **Gun last-kill line:** "Counting or not counting gang violence?"

### Controls (web / intended iOS)

| Action | Keys | Touch |
|--------|------|-------|
| Move | WASD / Arrows | Virtual stick |
| Punch | J / Z | PUNCH |
| Kick | K / X | KICK |
| Jump | Space / Shift | JUMP |
| Riff special | L / C (meter) | RIFF |
| Gun | F / U / G (after wave 3) | GUN |

## Privacy

This repository is **private**. Do not make it public without reviewing assets and any personal reference art.

## Backup tips

- Keep this GitHub repo as source of truth for assets
- Also copy any `.tar.gz` / Xcode project into **iCloud Drive**
- After major changes, tag a release or zip with a date in the filename

---
*Pushed via Grok · 2026-08-06*
