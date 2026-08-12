# JJ: Night Brawl

Private backup of **JJ: Night Brawl** — a 32-bit side-scrolling beat-em-up.

## Repo contents

This commit backs up the **art/assets** recovered from the project workspace:

- `assets/map/` — parallax backgrounds (sky, far, mid)
- `assets/sprites/jj/` — protagonist sheets (idle, walk, attack, hurt)
- `assets/sprites/enemy/` — enemy sheets (idle, walk, attack)
- `assets/sprites/fx/` — impact FX
- `assets/audio/tdm-8bit.mp3` — title / menu 8-bit theme (loops title → menu)

Game-ready sheets are named `sheet-transparent.png` (magenta keyed).
`pipeline-meta.json` files record sheet grid / frame info.

> **Note:** The full Xcode/Swift source and complete web engine lived in an earlier build session.
> This repo starts with assets + documentation so nothing is lost while source is re-assembled or re-exported.

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
