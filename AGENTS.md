# AGENTS.md

## Cursor Cloud specific instructions

This repo is **JJ: Night Brawl**, a browser beat-em-up game. The only runnable project is the
Vite + React web app in `web/` (canvas engine under `web/src/game/`). The `ios/` directory is
partial Swift stubs and is not buildable. Assets live in the repo-root `assets/` folder and are
served at `/assets/...` by a custom Vite middleware (`web/vite.config.ts`), so run all commands
from `web/`.

- Package manager is **npm** (`web/package-lock.json`); Node 22 works. The startup update script
  already runs `npm --prefix web ci`.
- Standard scripts are defined in `web/package.json`. Run them from `web/`:
  - Dev server: `npm run dev` (Vite on `0.0.0.0:5173`).
  - Build: `npm run build` (runs `tsc --noEmit` then `vite build`).
  - Typecheck only: `npm run typecheck`.
  - Asset check: `npm run check:assets` (verifies the 33 runtime PNG/MP3/MP4 assets exist).
- There is **no ESLint config**; the closest "lint" gate is `npm run typecheck` (plus
  `npm run check:assets`).
- Gameplay flow for manual testing: click the title card once to open the menu, choose Story or
  Endless, then click the game canvas to focus it before using the keyboard. Controls: WASD/arrows
  move, J/Z punch, K/X kick, Space/Shift jump, L riff special, F gun (after wave 3), M mute,
  Esc pause. Enemies are aggressive and can knock JJ out quickly.
- Test hook: the game exposes `window.__controlsTest` (see `web/src/game/GameCanvas.tsx`) with
  helpers like `start()`, `spawnOneNear()`, `queue()`, and getters for scripted/automated testing.
